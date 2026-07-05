module Conversations
  class MessagesController < ApplicationController
    include ActionController::Live

    before_action :set_conversation

    def create
      @message = @conversation.messages.build(
        role: "user",
        content: message_params[:content]
      )

      unless @message.save
        flash[:alert] = "Message cannot be empty."
        return redirect_to @conversation
      end

      auto_title_conversation
      stream_assistant_response(messages: @conversation.messages.to_a)
    rescue AI::Error => e
      stream_error_event(e.message)
    end

    def regenerate
      messages = @conversation.messages.to_a
      messages.pop if messages.last&.role == "assistant"
      stream_assistant_response(messages: messages, regenerate: true)
    rescue AI::Error => e
      stream_error_event(e.message)
    end

    private

    def set_conversation
      @conversation = Conversation.find(params[:conversation_id])
    end

    def message_params
      params.require(:message).permit(:content)
    end

    def chat_service
      @chat_service ||= AI::ChatService.new
    end

    def auto_title_conversation
      return unless @conversation.title == "New Chat"

      @conversation.update!(title: @message.content.truncate(50, separator: " "))
    end

    def stream_assistant_response(messages:, regenerate: false)
      response.headers["Content-Type"] = "text/event-stream"
      response.headers["Cache-Control"] = "no-cache"
      response.headers["X-Accel-Buffering"] = "no"

      sse = SSE.new(response.stream, event: "token")

      chat_response = chat_service.chat_with_history_streaming(messages) do |delta|
        sse.write({ content: delta })
      end

      if regenerate
        @conversation.messages.where(role: "assistant").last&.destroy!
      end

      assistant = @conversation.messages.create!(
        role: "assistant",
        content: chat_response.content,
        token_count: chat_response.usage[:total_tokens]
      )

      sse.write({
        message_id: assistant.id,
        token_count: chat_response.usage[:total_tokens]
      }, event: "done")

      sse.close
    end

    def stream_error_event(message)
      response.headers["Content-Type"] = "text/event-stream"
      response.headers["Cache-Control"] = "no-cache"
      response.headers["X-Accel-Buffering"] = "no"

      sse = SSE.new(response.stream)
      sse.write({ error: message }, event: "error")
      sse.close
    end
  end
end

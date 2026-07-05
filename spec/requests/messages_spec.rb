require "rails_helper"

RSpec.describe "Messages", type: :request do
  let(:conversation) { Conversation.create!(title: "New Chat") }
  let(:chat_service) { instance_double(AI::ChatService) }
  let(:chat_response) do
    AI::ChatResponse.new(
      content: "Hello! How can I help you?",
      model: "gpt-4o",
      usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 }
    )
  end

  before do
    allow(AI::ChatService).to receive(:new).and_return(chat_service)
    allow(chat_service).to receive(:chat_with_history_streaming) do |*_args, &block|
      block.call("Hello! ") if block
      block.call("How can I help you?") if block
      chat_response
    end
  end

  describe "POST /conversations/:conversation_id/messages" do
    it "creates a user message and an assistant message" do
      expect {
        post conversation_messages_path(conversation), params: { message: { content: "Hi" } }
      }.to change(conversation.messages, :count).by(2)

      expect(conversation.messages.first.role).to eq("user")
      expect(conversation.messages.first.content).to eq("Hi")
      expect(conversation.messages.last.role).to eq("assistant")
      expect(conversation.messages.last.content).to eq("Hello! How can I help you?")
      expect(conversation.messages.last.token_count).to eq(15)
    end

    it "auto-titles the conversation on first message" do
      expect {
        post conversation_messages_path(conversation), params: { message: { content: "What is Ruby on Rails?" } }
      }.to change(conversation.messages, :count).by(2)

      expect(conversation.reload.title).to eq("What is Ruby on Rails?")
    end

    it "does not retitle an already-titled conversation" do
      conversation.update!(title: "My Chat")

      expect {
        post conversation_messages_path(conversation), params: { message: { content: "Hello" } }
      }.to change(conversation.messages, :count).by(2)

      expect(conversation.reload.title).to eq("My Chat")
    end

    it "calls ChatService with conversation history" do
      post conversation_messages_path(conversation), params: { message: { content: "Hi" } }
      expect(chat_service).to have_received(:chat_with_history_streaming).with(
        an_instance_of(Array)
      )
    end

    it "returns SSE events in the response body" do
      post conversation_messages_path(conversation), params: { message: { content: "Hi" } }

      expect(response.content_type).to eq("text/event-stream")
      expect(response.body).to include("event: token")
      expect(response.body).to include("event: done")
      expect(response.body).to include("Hello! ")
      expect(response.body).to include("message_id")
      expect(response.body).to include("token_count")
    end

    it "streams tokens via SSE events" do
      post conversation_messages_path(conversation), params: { message: { content: "Hi" } }

      expect(response.body).to include('data: {"content":"Hello! "}')
      expect(response.body).to include('data: {"content":"How can I help you?"}')
    end

    context "when AI service raises an error" do
      before do
        allow(chat_service).to receive(:chat_with_history_streaming).and_raise(AI::APIError, "API unavailable")
      end

      it "creates the user message but sends an error SSE event" do
        expect {
          post conversation_messages_path(conversation), params: { message: { content: "Hi" } }
        }.to change(conversation.messages, :count).by(1)

        expect(response.content_type).to eq("text/event-stream")
        expect(response.body).to include("event: error")
        expect(response.body).to include("API unavailable")
      end
    end

    context "with empty message" do
      it "shows an alert and redirects" do
        post conversation_messages_path(conversation), params: { message: { content: "" } }
        expect(flash[:alert]).to eq("Message cannot be empty.")
        expect(response).to redirect_to(conversation_path(conversation))
      end
    end
  end

  describe "POST /conversations/:conversation_id/messages/regenerate" do
    let!(:user_message) { conversation.messages.create!(role: "user", content: "Hi") }
    let!(:assistant_message) { conversation.messages.create!(role: "assistant", content: "Old response", token_count: 5) }

    it "replaces the last assistant message" do
      expect {
        post regenerate_conversation_messages_path(conversation)
      }.not_to change(conversation.messages, :count)

      expect(conversation.messages.reload.last.content).to eq("Hello! How can I help you?")
    end

    it "preserves the user message" do
      post regenerate_conversation_messages_path(conversation)

      expect(conversation.messages.reload.first.role).to eq("user")
      expect(conversation.messages.first.content).to eq("Hi")
    end

    it "returns SSE events" do
      post regenerate_conversation_messages_path(conversation)

      expect(response.content_type).to eq("text/event-stream")
      expect(response.body).to include("event: token")
      expect(response.body).to include("event: done")
    end

    context "when there is no assistant message" do
      before { assistant_message.destroy! }

      it "still works and creates a new assistant message" do
        expect {
          post regenerate_conversation_messages_path(conversation)
        }.to change(conversation.messages, :count).by(1)

        expect(conversation.messages.last.content).to eq("Hello! How can I help you?")
      end
    end

    context "when AI service raises an error" do
      before do
        allow(chat_service).to receive(:chat_with_history_streaming).and_raise(AI::APIError, "Regeneration failed")
      end

      it "sends an error SSE event and preserves the old assistant message" do
        expect {
          post regenerate_conversation_messages_path(conversation)
        }.not_to change(conversation.messages, :count)

        expect(conversation.messages.reload.last.content).to eq("Old response")
        expect(response.body).to include("event: error")
        expect(response.body).to include("Regeneration failed")
      end
    end
  end
end

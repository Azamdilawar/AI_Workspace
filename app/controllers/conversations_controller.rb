class ConversationsController < ApplicationController
  before_action :set_conversation, only: [ :show, :update, :destroy ]

  def index
    @conversations = Conversation.order(updated_at: :desc)
    @conversation = @conversations.first

    if @conversation
      @messages = @conversation.messages.to_a
      @message = @conversation.messages.build
    end
  end

  def show
    @conversations = Conversation.order(updated_at: :desc)
    @messages = @conversation.messages.to_a
    @message = @conversation.messages.build
  end

  def create
    @conversation = Conversation.create!(title: "New Chat")
    redirect_to @conversation
  end

  def update
    @conversation.update!(title: params[:conversation][:title])
    redirect_to @conversation, notice: "Conversation renamed."
  end

  def destroy
    @conversation.destroy!
    redirect_to conversations_path, notice: "Conversation deleted."
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:id])
  end
end

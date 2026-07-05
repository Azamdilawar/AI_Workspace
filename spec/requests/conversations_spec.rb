require "rails_helper"

RSpec.describe "Conversations", type: :request do
  describe "GET /conversations" do
    it "renders the conversations index" do
      get conversations_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("AI Chat")
    end

    it "shows existing conversations" do
      conversation = Conversation.create!(title: "Test Chat")
      get conversations_path
      expect(response.body).to include("Test Chat")
    end
  end

  describe "GET /conversations/:id" do
    it "renders the conversation with messages" do
      conversation = Conversation.create!(title: "Test Chat")
      conversation.messages.create!(role: "user", content: "Hello")
      conversation.messages.create!(role: "assistant", content: "Hi there")

      get conversation_path(conversation)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Hello")
      expect(response.body).to include("Hi there")
    end
  end

  describe "POST /conversations" do
    it "creates a new conversation" do
      expect {
        post conversations_path
      }.to change(Conversation, :count).by(1)

      expect(response).to redirect_to(conversation_path(Conversation.last))
    end
  end

  describe "PATCH /conversations/:id" do
    it "renames the conversation" do
      conversation = Conversation.create!(title: "New Chat")
      patch conversation_path(conversation), params: { conversation: { title: "Renamed" } }
      expect(conversation.reload.title).to eq("Renamed")
      expect(response).to redirect_to(conversation_path(conversation))
      expect(flash[:notice]).to eq("Conversation renamed.")
    end
  end

  describe "DELETE /conversations/:id" do
    it "deletes the conversation and its messages" do
      conversation = Conversation.create!(title: "Test Chat")
      conversation.messages.create!(role: "user", content: "Hello")
      conversation.messages.create!(role: "assistant", content: "Hi")

      expect {
        delete conversation_path(conversation)
      }.to change(Conversation, :count).by(-1)
       .and change(Message, :count).by(-2)

      expect(response).to redirect_to(conversations_path)
      expect(flash[:notice]).to eq("Conversation deleted.")
    end
  end
end

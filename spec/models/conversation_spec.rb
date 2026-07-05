require "rails_helper"

RSpec.describe Conversation, type: :model do
  describe "associations" do
    it "has many messages with dependent destroy" do
      conversation = Conversation.create!(title: "Test")
      conversation.messages.create!(role: "user", content: "Hi")
      conversation.messages.create!(role: "assistant", content: "Hello")

      expect { conversation.destroy! }.to change(Message, :count).by(-2)
    end
  end

  describe "validations" do
    it "requires a title" do
      conversation = Conversation.new(title: nil)
      expect(conversation).not_to be_valid
      expect(conversation.errors[:title]).to include("can't be blank")
    end
  end

  describe "default scope" do
    it "orders messages by created_at" do
      conversation = Conversation.create!(title: "Test")
      first = conversation.messages.create!(role: "user", content: "First")
      second = conversation.messages.create!(role: "assistant", content: "Second")

      expect(conversation.messages.to_a).to eq([first, second])
    end
  end
end

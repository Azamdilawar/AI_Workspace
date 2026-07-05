require "rails_helper"

RSpec.describe Message, type: :model do
  let(:conversation) { Conversation.create!(title: "Test") }

  describe "associations" do
    it "belongs to a conversation" do
      message = conversation.messages.create!(role: "user", content: "Hi")
      expect(message.conversation).to eq(conversation)
    end

    it "updates conversation timestamp on create" do
      old_time = 1.hour.ago
      conversation.update!(updated_at: old_time)

      conversation.messages.create!(role: "user", content: "Hi")
      expect(conversation.reload.updated_at).to be > old_time
    end
  end

  describe "validations" do
    it "requires a role" do
      message = conversation.messages.build(role: nil, content: "Hi")
      expect(message).not_to be_valid
      expect(message.errors[:role]).to include("can't be blank")
    end

    it "requires content" do
      message = conversation.messages.build(role: "user", content: nil)
      expect(message).not_to be_valid
      expect(message.errors[:content]).to include("can't be blank")
    end

    it "validates role inclusion" do
      message = conversation.messages.build(role: "admin", content: "Hi")
      expect(message).not_to be_valid
      expect(message.errors[:role]).to include("is not included in the list")
    end

    it "accepts valid roles" do
      %w[user assistant system].each do |role|
        message = conversation.messages.build(role: role, content: "Hi")
        expect(message).to be_valid
      end
    end
  end
end

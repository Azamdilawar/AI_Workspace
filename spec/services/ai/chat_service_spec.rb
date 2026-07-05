require "rails_helper"

RSpec.describe AI::ChatService do
  let(:client) { instance_double(AI::Client) }
  let(:response) do
    AI::ChatResponse.new(
      content: "Hello! How can I help you?",
      model: "gpt-4o",
      usage: { prompt_tokens: 5, completion_tokens: 7, total_tokens: 12 }
    )
  end

  before do
    allow(client).to receive(:chat).and_return(response)
  end

  describe "#call" do
    subject(:service) { described_class.new(client: client) }

    it "calls the client with the prompt message" do
      expect(client).to receive(:chat).with(
        [{ role: "user", content: "What is AI?" }],
        hash_including({})
      )
      service.call("What is AI?")
    end

    it "returns a ChatResponse" do
      result = service.call("Hello")
      expect(result).to be_an(AI::ChatResponse)
    end

    it "returns the expected content" do
      result = service.call("Hello")
      expect(result.content).to eq("Hello! How can I help you?")
    end

    context "when passing options" do
      it "forwards model option to the client" do
        expect(client).to receive(:chat).with(
          [{ role: "user", content: "Hi" }],
          hash_including(model: "gpt-4o-mini")
        )
        service.call("Hi", model: "gpt-4o-mini")
      end

      it "forwards temperature option to the client" do
        expect(client).to receive(:chat).with(
          [{ role: "user", content: "Hi" }],
          hash_including(temperature: 0.5)
        )
        service.call("Hi", temperature: 0.5)
      end

      it "forwards max_tokens option to the client" do
        expect(client).to receive(:chat).with(
          [{ role: "user", content: "Hi" }],
          hash_including(max_tokens: 512)
        )
        service.call("Hi", max_tokens: 512)
      end

      it "forwards extra options to the client" do
        expect(client).to receive(:chat).with(
          [{ role: "user", content: "Hi" }],
          hash_including(user: "test-user")
        )
        service.call("Hi", user: "test-user")
      end
    end
  end

  describe "#chat_with_history" do
    subject(:service) { described_class.new(client: client) }

    let(:history_messages) do
      [
        instance_double(Message, role: "user", content: "What is AI?"),
        instance_double(Message, role: "assistant", content: "AI is artificial intelligence.")
      ]
    end

    it "calls the client with full conversation history" do
      expected_messages = [
        { role: "user", content: "What is AI?" },
        { role: "assistant", content: "AI is artificial intelligence." }
      ]

      expect(client).to receive(:chat).with(
        expected_messages,
        hash_including({})
      )
      service.chat_with_history(history_messages)
    end

    it "returns a ChatResponse" do
      result = service.chat_with_history(history_messages)
      expect(result).to be_an(AI::ChatResponse)
    end

    context "when passing options" do
      it "forwards model option to the client" do
        expect(client).to receive(:chat).with(
          anything,
          hash_including(model: "gpt-4o-mini")
        )
        service.chat_with_history(history_messages, model: "gpt-4o-mini")
      end
    end
  end

  describe "#chat_with_history_streaming" do
    subject(:service) { described_class.new(client: client) }

    let(:history_messages) do
      [
        instance_double(Message, role: "user", content: "What is AI?"),
        instance_double(Message, role: "assistant", content: "AI is artificial intelligence.")
      ]
    end

    let(:stream_response) do
      AI::ChatResponse.new(
        content: "AI stands for Artificial Intelligence.",
        model: "gpt-4o",
        usage: { prompt_tokens: 20, completion_tokens: 8, total_tokens: 28 }
      )
    end

    before do
      allow(client).to receive(:stream_chat).and_yield("AI stands ")
        .and_yield("for Artificial ")
        .and_yield("Intelligence.")
        .and_return(stream_response)
    end

    it "calls the client with full conversation history" do
      expected_messages = [
        { role: "user", content: "What is AI?" },
        { role: "assistant", content: "AI is artificial intelligence." }
      ]

      service.chat_with_history_streaming(history_messages) { |_| }
      expect(client).to have_received(:stream_chat).with(
        expected_messages,
        hash_including({})
      )
    end

    it "yields tokens to the block" do
      tokens = []

      service.chat_with_history_streaming(history_messages) do |delta|
        tokens << delta
      end

      expect(tokens).to eq(["AI stands ", "for Artificial ", "Intelligence."])
    end

    it "returns a ChatResponse" do
      result = service.chat_with_history_streaming(history_messages) { |_| }
      expect(result).to be_an(AI::ChatResponse)
      expect(result.content).to eq("AI stands for Artificial Intelligence.")
      expect(result.usage[:total_tokens]).to eq(28)
    end

    context "when passing options" do
      it "forwards model option to the client" do
        service.chat_with_history_streaming(history_messages, model: "gpt-4o-mini") { |_| }
        expect(client).to have_received(:stream_chat).with(
          anything,
          hash_including(model: "gpt-4o-mini")
        )
      end
    end

    context "when no block is given" do
      before do
        allow(client).to receive(:stream_chat).and_return(stream_response)
      end

      it "still returns a ChatResponse" do
        result = service.chat_with_history_streaming(history_messages)
        expect(result).to be_an(AI::ChatResponse)
      end
    end
  end

  describe "default client" do
    it "creates a default AI::Client when none is provided" do
      allow(AI::Client).to receive(:new).and_return(client)
      service = described_class.new
      expect(service.call("Hello")).to be_an(AI::ChatResponse)
    end
  end
end

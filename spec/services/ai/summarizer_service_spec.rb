require "rails_helper"

RSpec.describe AI::SummarizerService do
  let(:client) { instance_double(AI::Client) }
  let(:response) do
    AI::ChatResponse.new(
      content: "The key takeaway from the article is that AI is transforming industries.",
      model: "gpt-4o",
      usage: { prompt_tokens: 150, completion_tokens: 20, total_tokens: 170 }
    )
  end

  let(:stream_response) do
    AI::ChatResponse.new(
      content: "Summary: AI is transforming industries through automation.",
      model: "gpt-4o",
      usage: { prompt_tokens: 150, completion_tokens: 15, total_tokens: 165 }
    )
  end

  let(:default_params) do
    {
      summary_type: "general",
      length: "medium",
      tone: "neutral",
      text: "Artificial intelligence is rapidly transforming the way businesses operate. Companies are adopting AI-powered tools to automate repetitive tasks, improve decision-making, and enhance customer experiences."
    }
  end

  before do
    allow(client).to receive(:chat).and_return(response)
  end

  describe "#summarize" do
    subject(:service) { described_class.new(client: client) }

    it "calls the client with system and user messages" do
      expect(client).to receive(:chat) do |messages, options|
        expect(messages).to be_an(Array)
        expect(messages.length).to eq(2)
        expect(messages[0][:role]).to eq("system")
        expect(messages[1][:role]).to eq("user")
        expect(options[:temperature]).to eq(0.3)
      end.and_return(response)

      service.summarize(**default_params)
    end

    it "returns a ChatResponse" do
      result = service.summarize(**default_params)
      expect(result).to be_an(AI::ChatResponse)
    end

    it "returns the expected content" do
      result = service.summarize(**default_params)
      expect(result.content).to include("AI is transforming")
    end

    context "with different summary types" do
      it "builds prompt with general summary type" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("General Summary")
          expect(user_msg).to include("comprehensive overview")
        end.and_return(response)

        service.summarize(**default_params)
      end

      it "builds prompt with bullet points type" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("Bullet Points")
          expect(user_msg).to include("list of concise bullet points")
        end.and_return(response)

        service.summarize(**default_params.merge(summary_type: "bullets"))
      end

      it "builds prompt with executive summary type" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("Executive Summary")
        end.and_return(response)

        service.summarize(**default_params.merge(summary_type: "executive"))
      end

      it "builds prompt with key takeaways type" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("Key Takeaways")
        end.and_return(response)

        service.summarize(**default_params.merge(summary_type: "takeaways"))
      end

      it "builds prompt with action items type" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("Action Items")
        end.and_return(response)

        service.summarize(**default_params.merge(summary_type: "actions"))
      end
    end

    context "with different lengths" do
      it "builds prompt with short length" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("Short")
          expect(user_msg).to include("2 to 3 sentences")
        end.and_return(response)

        service.summarize(**default_params.merge(length: "short"))
      end

      it "builds prompt with medium length" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("Medium")
          expect(user_msg).to include("1 to 2 paragraphs")
        end.and_return(response)

        service.summarize(**default_params.merge(length: "medium"))
      end

      it "builds prompt with long length" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("Long")
          expect(user_msg).to include("3 to 4 paragraphs")
        end.and_return(response)

        service.summarize(**default_params.merge(length: "long"))
      end
    end

    context "with different tones" do
      it "builds prompt with neutral tone" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("Neutral")
          expect(user_msg).to include("objective, unbiased")
        end.and_return(response)

        service.summarize(**default_params)
      end

      it "builds prompt with professional tone" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("Professional")
          expect(user_msg).to include("formal, business-appropriate")
        end.and_return(response)

        service.summarize(**default_params.merge(tone: "professional"))
      end

      it "builds prompt with simple tone" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("Simple")
          expect(user_msg).to include("plain, easy-to-understand")
        end.and_return(response)

        service.summarize(**default_params.merge(tone: "simple"))
      end

      it "defaults to neutral for unknown tone" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("Neutral")
        end.and_return(response)

        service.summarize(**default_params.merge(tone: "unknown"))
      end
    end

    context "with empty text" do
      it "handles empty text gracefully" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("No text provided")
        end.and_return(response)

        service.summarize(**default_params.merge(text: ""))
      end

      it "handles nil text gracefully" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("No text provided")
        end.and_return(response)

        service.summarize(**default_params.merge(text: nil))
      end
    end

    context "with streaming" do
      before do
        allow(client).to receive(:stream_chat).and_yield("Summary: ")
          .and_yield("AI is transforming")
          .and_yield(" industries through")
          .and_yield(" automation.")
          .and_return(stream_response)
      end

      it "calls stream_chat when a block is given" do
        expect(client).to receive(:stream_chat) do |messages, options|
          expect(messages.length).to eq(2)
          expect(options[:temperature]).to eq(0.3)
        end.and_return(stream_response)

        service.summarize(**default_params) { |_| }
      end

      it "yields tokens to the block" do
        tokens = []

        service.summarize(**default_params) do |delta|
          tokens << delta
        end

        expect(tokens).to eq(["Summary: ", "AI is transforming", " industries through", " automation."])
      end

      it "returns a ChatResponse from stream" do
        result = service.summarize(**default_params) { |_| }
        expect(result).to be_an(AI::ChatResponse)
        expect(result.content).to eq("Summary: AI is transforming industries through automation.")
        expect(result.usage[:total_tokens]).to eq(165)
      end
    end
  end

  describe "default client" do
    it "creates a default AI::Client when none is provided" do
      allow(AI::Client).to receive(:new).and_return(client)
      service = described_class.new
      expect(service.summarize(**default_params)).to be_an(AI::ChatResponse)
    end
  end
end

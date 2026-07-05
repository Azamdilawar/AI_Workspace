require "rails_helper"

RSpec.describe AI::EmailService do
  let(:client) { instance_double(AI::Client) }
  let(:response) do
    AI::ChatResponse.new(
      content: "Subject: Thank You\n\nDear Team,\n\nThank you for your support.\n\nBest regards,\nJohn",
      model: "gpt-4o",
      usage: { prompt_tokens: 50, completion_tokens: 30, total_tokens: 80 }
    )
  end

  let(:stream_response) do
    AI::ChatResponse.new(
      content: "Subject: Thank You\n\nThanks!",
      model: "gpt-4o",
      usage: { prompt_tokens: 50, completion_tokens: 30, total_tokens: 80 }
    )
  end

  let(:default_params) do
    {
      tone: "professional",
      email_type: "thank_you",
      length: "medium",
      context: "Thank the team for their hard work this quarter."
    }
  end

  before do
    allow(client).to receive(:chat).and_return(response)
  end

  describe "#generate" do
    subject(:service) { described_class.new(client: client) }

    it "calls the client with system and user messages" do
      expect(client).to receive(:chat) do |messages, options|
        expect(messages).to be_an(Array)
        expect(messages.length).to eq(2)
        expect(messages[0][:role]).to eq("system")
        expect(messages[1][:role]).to eq("user")
        expect(options[:temperature]).to eq(0.2)
      end.and_return(response)

      service.generate(**default_params)
    end

    it "returns a ChatResponse" do
      result = service.generate(**default_params)
      expect(result).to be_an(AI::ChatResponse)
    end

    it "returns the expected content" do
      result = service.generate(**default_params)
      expect(result.content).to include("Subject:")
      expect(result.content).to include("Thank you for your support")
    end

    context "with different tones" do
      it "builds prompt with professional tone" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("professional")
          expect(user_msg).to include("business-appropriate")
        end.and_return(response)

        service.generate(**default_params)
      end

      it "builds prompt with casual tone" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("casual")
          expect(user_msg).to include("friendly")
        end.and_return(response)

        service.generate(**default_params.merge(tone: "casual"))
      end

      it "builds prompt with formal tone" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("formal")
        end.and_return(response)

        service.generate(**default_params.merge(tone: "formal"))
      end

      it "defaults to professional for unknown tone" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("professional")
        end.and_return(response)

        service.generate(**default_params.merge(tone: "unknown"))
      end
    end

    context "with different email types" do
      it "builds prompt with outbound type" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("Sales Outreach")
        end.and_return(response)

        service.generate(**default_params.merge(email_type: "outbound"))
      end

      it "builds prompt with follow_up type" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("Follow-up")
        end.and_return(response)

        service.generate(**default_params.merge(email_type: "follow_up"))
      end

      it "builds prompt with introduction type" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("Introduction")
        end.and_return(response)

        service.generate(**default_params.merge(email_type: "introduction"))
      end
    end

    context "with different lengths" do
      it "builds prompt with short length" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("concise")
          expect(user_msg).to include("2 to 3")
        end.and_return(response)

        service.generate(**default_params.merge(length: "short"))
      end

      it "builds prompt with medium length" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("3 to 4")
        end.and_return(response)

        service.generate(**default_params.merge(length: "medium"))
      end

      it "builds prompt with long length" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("4 to 5")
        end.and_return(response)

        service.generate(**default_params.merge(length: "long"))
      end
    end

    context "with empty context" do
      it "handles empty context gracefully" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("No additional context provided")
        end.and_return(response)

        service.generate(**default_params.merge(context: ""))
      end

      it "handles nil context gracefully" do
        expect(client).to receive(:chat) do |messages, _|
          user_msg = messages[1][:content]
          expect(user_msg).to include("No additional context provided")
        end.and_return(response)

        service.generate(**default_params.merge(context: nil))
      end
    end

    context "with streaming" do
      before do
        allow(client).to receive(:stream_chat).and_yield("Subject: ")
          .and_yield("Thank")
          .and_yield(" You")
          .and_yield("\n\n")
          .and_yield("Thanks!")
          .and_return(stream_response)
      end

      it "calls stream_chat when a block is given" do
        expect(client).to receive(:stream_chat) do |messages, options|
          expect(messages.length).to eq(2)
          expect(options[:temperature]).to eq(0.2)
        end.and_return(stream_response)

        service.generate(**default_params) { |_| }
      end

      it "yields tokens to the block" do
        tokens = []

        service.generate(**default_params) do |delta|
          tokens << delta
        end

        expect(tokens).to eq(["Subject: ", "Thank", " You", "\n\n", "Thanks!"])
      end

      it "returns a ChatResponse from stream" do
        result = service.generate(**default_params) { |_| }
        expect(result).to be_an(AI::ChatResponse)
        expect(result.content).to eq("Subject: Thank You\n\nThanks!")
        expect(result.usage[:total_tokens]).to eq(80)
      end
    end
  end

  describe "default client" do
    it "creates a default AI::Client when none is provided" do
      allow(AI::Client).to receive(:new).and_return(client)
      service = described_class.new
      expect(service.generate(**default_params)).to be_an(AI::ChatResponse)
    end
  end
end

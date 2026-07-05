require "rails_helper"

RSpec.describe AI::Client do
  let(:config) do
    AI::Configuration.new.tap do |c|
      c.openai_api_key = "sk-test"
      c.api_base_url = nil
      c.default_model = "gpt-4o"
      c.default_temperature = 0.7
      c.timeout = 30
      c.max_tokens = 2048
    end
  end

  let(:openai_instance) { instance_double(OpenAI::Client) }
  let(:response_data) do
    {
      "id" => "chatcmpl-123",
      "object" => "chat.completion",
      "created" => 1_234_567_890,
      "model" => "gpt-4o",
      "choices" => [
        {
          "index" => 0,
          "message" => { "role" => "assistant", "content" => "Hello, world!" },
          "finish_reason" => "stop"
        }
      ],
      "usage" => { "prompt_tokens" => 10, "completion_tokens" => 5, "total_tokens" => 15 }
    }
  end
  let(:messages) { [{ role: "user", content: "Hi" }] }
  let(:parameters) do
    {
      model: "gpt-4o",
      messages: messages,
      temperature: 0.7,
      max_tokens: 2048
    }
  end

  before do
    allow(OpenAI::Client).to receive(:new).with(
      access_token: "sk-test",
      request_timeout: 30,
      log_errors: false
    ).and_return(openai_instance)

    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe "#initialize" do
    it "raises ConfigurationError when API key is missing" do
      config.openai_api_key = nil
      expect { described_class.new(configuration: config) }
        .to raise_error(AI::ConfigurationError, /API key is missing/)
    end

    it "raises ConfigurationError when API key is blank" do
      config.openai_api_key = ""
      expect { described_class.new(configuration: config) }
        .to raise_error(AI::ConfigurationError, /API key is missing/)
    end

    it "initializes successfully with a valid config" do
      client = described_class.new(configuration: config)
      expect(client).to be_a(described_class)
    end

    it "passes uri_base to OpenAI::Client when api_base_url is configured" do
      config.api_base_url = "https://openrouter.ai/api/v1"

      expect(OpenAI::Client).to receive(:new).with(
        access_token: "sk-test",
        request_timeout: 30,
        log_errors: false,
        uri_base: "https://openrouter.ai/api/v1"
      ).and_return(openai_instance)

      described_class.new(configuration: config)
    end

    it "does not pass uri_base when api_base_url is not configured" do
      config.api_base_url = nil

      expect(OpenAI::Client).to receive(:new).with(
        access_token: "sk-test",
        request_timeout: 30,
        log_errors: false
      ).and_return(openai_instance)

      described_class.new(configuration: config)
    end
  end

  describe "#chat" do
    subject(:client) { described_class.new(configuration: config) }

    before do
      allow(openai_instance).to receive(:chat).with(parameters: parameters).and_return(response_data)
    end

    it "sends messages to the OpenAI client" do
      expect(openai_instance).to receive(:chat).with(parameters: parameters)
      client.chat(messages)
    end

    it "returns a ChatResponse" do
      response = client.chat(messages)
      expect(response).to be_an(AI::ChatResponse)
    end

    it "includes the expected content" do
      response = client.chat(messages)
      expect(response.content).to eq("Hello, world!")
    end

    it "includes the model name" do
      response = client.chat(messages)
      expect(response.model).to eq("gpt-4o")
    end

    it "includes usage data" do
      response = client.chat(messages)
      expect(response.usage).to eq(
        prompt_tokens: 10,
        completion_tokens: 5,
        total_tokens: 15
      )
    end

    it "logs success with model and duration" do
      expect(Rails.logger).to receive(:info).with(/\[AI::Client\] Model=gpt-4o Duration=/)
      client.chat(messages)
    end

    context "when overriding defaults" do
      let(:custom_params) do
        {
          model: "gpt-4o-mini",
          messages: messages,
          temperature: 0.3,
          max_tokens: 1024
        }
      end

      before do
        allow(openai_instance).to receive(:chat).with(parameters: custom_params).and_return(response_data)
      end

      it "uses custom model" do
        expect(openai_instance).to receive(:chat).with(parameters: custom_params)
        client.chat(messages, model: "gpt-4o-mini", temperature: 0.3, max_tokens: 1024)
      end
    end

    context "when passing additional options" do
      it "merges extra options into parameters" do
        extra_params = parameters.merge(user: "test-user")
        expect(openai_instance).to receive(:chat).with(parameters: extra_params).and_return(response_data)
        client.chat(messages, user: "test-user")
      end
    end
  end

  describe "#stream_chat" do
    subject(:client) { described_class.new(configuration: config) }

    let(:streamed_tokens) { [] }
    let(:stream_handler) { proc { |chunk| streamed_tokens << chunk } }

    let(:chunk1) do
      {
        "choices" => [
          { "delta" => { "content" => "Hello" }, "index" => 0, "finish_reason" => nil }
        ]
      }
    end

    let(:chunk2) do
      {
        "choices" => [
          { "delta" => { "content" => " world" }, "index" => 0, "finish_reason" => nil }
        ]
      }
    end

    let(:final_chunk) do
      {
        "choices" => [
          { "delta" => {}, "index" => 0, "finish_reason" => "stop" }
        ],
        "model" => "gpt-4o",
        "usage" => { "prompt_tokens" => 10, "completion_tokens" => 5, "total_tokens" => 15 }
      }
    end

    before do
      call_count = 0
      allow(openai_instance).to receive(:chat) do |params|
        stream_proc = params.dig(:parameters, :stream)
        stream_proc.call(chunk1) if stream_proc
        stream_proc.call(chunk2) if stream_proc
        stream_proc.call(final_chunk) if stream_proc
        "Hello world"
      end
    end

    it "sends messages with stream option" do
      expect(openai_instance).to receive(:chat) do |params|
        expect(params.dig(:parameters, :stream)).to be_a(Proc)
        expect(params.dig(:parameters, :messages)).to eq(messages)
      end

      client.stream_chat(messages)
    end

    it "yields content tokens to the block" do
      tokens = []
      client.stream_chat(messages) { |delta| tokens << delta }
      expect(tokens).to eq(["Hello", " world"])
    end

    it "returns a ChatResponse with full content" do
      response = client.stream_chat(messages) { |_| nil }
      expect(response).to be_an(AI::ChatResponse)
      expect(response.content).to eq("Hello world")
      expect(response.model).to eq("gpt-4o")
    end

    it "includes usage data from final chunk" do
      response = client.stream_chat(messages) { |_| nil }
      expect(response.usage).to eq(
        prompt_tokens: 10,
        completion_tokens: 5,
        total_tokens: 15
      )
    end

    it "logs success with model and duration" do
      expect(Rails.logger).to receive(:info).with(/\[AI::Client\] Model=gpt-4o Duration=/)
      client.stream_chat(messages) { |_| nil }
    end

    context "when no block is given" do
      it "still returns a ChatResponse" do
        response = client.stream_chat(messages)
        expect(response).to be_an(AI::ChatResponse)
        expect(response.content).to eq("Hello world")
      end
    end

    context "when overriding defaults" do
      it "uses custom model and temperature" do
        expect(openai_instance).to receive(:chat) do |params|
          expect(params.dig(:parameters, :model)).to eq("gpt-4o-mini")
          expect(params.dig(:parameters, :temperature)).to eq(0.3)
        end.and_return("custom response")

        client.stream_chat(messages, model: "gpt-4o-mini", temperature: 0.3)
      end
    end
  end

  describe "error handling" do
    subject(:client) { described_class.new(configuration: config) }

    before do
      allow(Rails.logger).to receive(:error)
    end

    it "handles Faraday::TimeoutError" do
      allow(openai_instance).to receive(:chat).and_raise(Faraday::TimeoutError, "execution expired")
      expect { client.chat(messages) }.to raise_error(AI::TimeoutError, /timed out/)
    end

    it "handles Faraday::ConnectionFailed" do
      allow(openai_instance).to receive(:chat).and_raise(Faraday::ConnectionFailed, "connection refused")
      expect { client.chat(messages) }.to raise_error(AI::NetworkError, /Connection failed/)
    end

    it "handles OpenAI authentication errors" do
      error = OpenAI::Error.new("Incorrect API key provided: sk-***. You can find your API key at https://platform.openai.com/account/api-keys.")
      allow(openai_instance).to receive(:chat).and_raise(error)
      expect { client.chat(messages) }.to raise_error(AI::AuthenticationError)
    end

    it "handles rate limit errors" do
      error = OpenAI::Error.new("Rate limit exceeded for API key. Limit: 10 per 1m. Please try again in 6s.")
      allow(openai_instance).to receive(:chat).and_raise(error)
      expect { client.chat(messages) }.to raise_error(AI::RateLimitError)
    end

    it "handles general API errors" do
      error = OpenAI::Error.new("Bad Request: invalid model")
      allow(openai_instance).to receive(:chat).and_raise(error)
      expect { client.chat(messages) }.to raise_error(AI::APIError)
    end

    it "handles unexpected StandardError" do
      allow(openai_instance).to receive(:chat).and_raise(StandardError.new("something went wrong"))
      expect { client.chat(messages) }.to raise_error(AI::APIError, /Unexpected error/)
    end

    it "logs errors" do
      allow(openai_instance).to receive(:chat).and_raise(OpenAI::Error.new("Bad Request"))
      expect(Rails.logger).to receive(:error).with(/\[AI::Client\] Error=/)
      expect { client.chat(messages) }.to raise_error(AI::Error)
    end

    describe "Faraday::ClientError handling (non-OpenAI providers)" do
      it "handles Faraday::UnauthorizedError (401) from provider" do
        error = Faraday::UnauthorizedError.new(status: 401, body: {"error" => {"message" => "Invalid credentials"}})
        allow(openai_instance).to receive(:chat).and_raise(error)
        expect { client.chat(messages) }.to raise_error(AI::AuthenticationError, /Invalid credentials/)
      end

      it "handles Faraday::ClientError with 429 status" do
        error = Faraday::TooManyRequestsError.new(status: 429, body: {"error" => {"message" => "Rate limit exceeded"}})
        allow(openai_instance).to receive(:chat).and_raise(error)
        expect { client.chat(messages) }.to raise_error(AI::RateLimitError, /Rate limit exceeded/)
      end

      it "handles Faraday::ClientError with generic status" do
        error = Faraday::BadRequestError.new(status: 400, body: {"error" => {"message" => "Bad request"}})
        allow(openai_instance).to receive(:chat).and_raise(error)
        expect { client.chat(messages) }.to raise_error(AI::APIError, /Bad request/)
      end

      it "handles Faraday::ClientError with string body" do
        error = Faraday::UnauthorizedError.new(status: 401, body: '{"error":{"message":"Invalid API key"}}')
        allow(openai_instance).to receive(:chat).and_raise(error)
        expect { client.chat(messages) }.to raise_error(AI::AuthenticationError, /Invalid API key/)
      end

      it "handles Faraday::ClientError with empty body" do
        error = Faraday::ServerError.new(status: 500, body: "")
        allow(openai_instance).to receive(:chat).and_raise(error)
        expect { client.chat(messages) }.to raise_error(AI::APIError)
      end
    end
  end
end

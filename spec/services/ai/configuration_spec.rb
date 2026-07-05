require "rails_helper"

RSpec.describe AI::Configuration do
  describe "default values" do
    it "reads OPENAI_API_KEY from environment" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("sk-test")
      config = described_class.new
      expect(config.openai_api_key).to eq("sk-test")
    end

    it "defaults model to gpt-4o" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("DEFAULT_MODEL").and_return(nil)
      config = described_class.new
      expect(config.default_model).to eq("gpt-4o")
    end

    it "defaults temperature to 0.7" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("DEFAULT_TEMPERATURE").and_return(nil)
      config = described_class.new
      expect(config.default_temperature).to eq(0.7)
    end

    it "defaults timeout to 30" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("AI_TIMEOUT").and_return(nil)
      config = described_class.new
      expect(config.timeout).to eq(30)
    end

    it "defaults max_tokens to 2048" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("AI_MAX_TOKENS").and_return(nil)
      config = described_class.new
      expect(config.max_tokens).to eq(2048)
    end

    it "defaults provider to :openai" do
      config = described_class.new
      expect(config.provider).to eq(:openai)
    end
  end

  describe "custom values" do
    it "allows setting custom values via accessors" do
      config = described_class.new
      config.default_model = "gpt-4o-mini"
      config.default_temperature = 0.5
      config.timeout = 60
      config.max_tokens = 4096

      expect(config.default_model).to eq("gpt-4o-mini")
      expect(config.default_temperature).to eq(0.5)
      expect(config.timeout).to eq(60)
      expect(config.max_tokens).to eq(4096)
    end
  end
end

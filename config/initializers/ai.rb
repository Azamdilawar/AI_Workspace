require Rails.root.join("app/services/ai/errors")
require Rails.root.join("app/services/ai/configuration")
require Rails.root.join("app/services/ai/chat_response")
require Rails.root.join("app/services/ai/client")
require Rails.root.join("app/services/ai/chat_service")

module AI
  class << self
    def config
      @config ||= AI::Configuration.new
    end

    def configure
      yield(config)
    end
  end
end

# Default application AI workspace configuration
# Provider-agnostic — swap providers by changing environment variables only.
AI.configure do |config|
  config.openai_api_key = ENV["OPENAI_API_KEY"]
  config.api_base_url = ENV["AI_BASE_URL"].presence
  config.default_model = ENV["DEFAULT_MODEL"] || "gpt-4o"
  config.default_temperature = (ENV["DEFAULT_TEMPERATURE"] || 0.7).to_f
  config.timeout = (ENV["AI_TIMEOUT"] || 30).to_i
  config.max_tokens = (ENV["AI_MAX_TOKENS"] || 2048).to_i
  config.provider = :openai
end

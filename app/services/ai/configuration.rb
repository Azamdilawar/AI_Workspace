module AI
  class Configuration
    attr_accessor :openai_api_key, :api_base_url, :default_model, :default_temperature, :timeout, :max_tokens, :provider

    def initialize
      @provider = :openai
      @openai_api_key = ENV["OPENAI_API_KEY"]
      @api_base_url = ENV["AI_BASE_URL"].presence
      @default_model = ENV["DEFAULT_MODEL"] || "gpt-4o"
      @default_temperature = (ENV["DEFAULT_TEMPERATURE"] || 0.7).to_f
      @timeout = (ENV["AI_TIMEOUT"] || 30).to_i
      @max_tokens = (ENV["AI_MAX_TOKENS"] || 2048).to_i
    end
  end
end

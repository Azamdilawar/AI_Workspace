module AI
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class AuthenticationError < Error; end
  class RateLimitError < Error; end
  class NetworkError < Error; end
  class TimeoutError < Error; end
  class APIError < Error; end
end

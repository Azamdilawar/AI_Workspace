module AI
  class Client
    def initialize(configuration: nil)
      @config = configuration || AI.config
      validate_config!
      @openai_client = build_client
    end

    def chat(messages, model: nil, temperature: nil, max_tokens: nil, **options)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      parameters = build_parameters(messages, model, temperature, max_tokens, options)

      response = @openai_client.chat(parameters: parameters)
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      log_success(parameters[:model], duration, response.dig("usage", "total_tokens"))
      build_response(response)
    rescue Faraday::TimeoutError => e
      log_error("timeout")
      raise TimeoutError, "Request timed out: #{e.message}"
    rescue Faraday::ConnectionFailed => e
      log_error("network_error")
      raise NetworkError, "Connection failed: #{e.message}"
    rescue Faraday::ClientError => e
      handle_faraday_error(e)
    rescue Faraday::ServerError => e
      handle_faraday_error(e)
    rescue OpenAI::Error => e
      handle_openai_error(e)
    rescue StandardError => e
      log_error("unexpected_error")
      raise APIError, "Unexpected error: #{e.message}"
    end

    def stream_chat(messages, model: nil, temperature: nil, max_tokens: nil, **options, &block)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      parameters = build_parameters(messages, model, temperature, max_tokens, options)

      accumulated = +""
      usage_data = {}
      final_model = parameters[:model]

      stream_handler = proc do |chunk|
        delta = chunk.dig("choices", 0, "delta", "content")
        if delta
          accumulated << delta
          block.call(delta) if block
        end

        finish_reason = chunk.dig("choices", 0, "finish_reason")
        if finish_reason
          usage_data = chunk["usage"] || {}
          final_model = chunk["model"] || final_model
        end
      end

      @openai_client.chat(
        parameters: parameters.merge(
          stream: stream_handler,
          stream_options: { include_usage: true }
        )
      )

      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      total_tokens = usage_data["total_tokens"]
      log_success(final_model, duration, total_tokens)

      AI::ChatResponse.new(
        content: accumulated,
        model: final_model,
        usage: {
          prompt_tokens: usage_data["prompt_tokens"],
          completion_tokens: usage_data["completion_tokens"],
          total_tokens: total_tokens
        }
      )
    rescue Faraday::TimeoutError => e
      log_error("timeout")
      raise TimeoutError, "Request timed out: #{e.message}"
    rescue Faraday::ConnectionFailed => e
      log_error("network_error")
      raise NetworkError, "Connection failed: #{e.message}"
    rescue Faraday::ClientError => e
      handle_faraday_error(e)
    rescue Faraday::ServerError => e
      handle_faraday_error(e)
    rescue OpenAI::Error => e
      handle_openai_error(e)
    rescue StandardError => e
      log_error("unexpected_error")
      raise APIError, "Unexpected error: #{e.message}"
    end

    # Generate embeddings for text
    # @param text [String] The text to embed
    # @param model [String] The embedding model to use
    # @return [Array<Float>] The embedding vector
    def embed(text, model: nil)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      embedding_model = model || "text-embedding-3-small"

      response = @openai_client.embeddings(
        parameters: {
          model: embedding_model,
          input: text
        }
      )

      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      embedding = response.dig("data", 0, "embedding")
      total_tokens = response.dig("usage", "total_tokens")

      log_embedding_success(embedding_model, duration, total_tokens, embedding&.length)
      embedding
    rescue Faraday::TimeoutError => e
      log_error("embedding_timeout")
      raise TimeoutError, "Embedding request timed out: #{e.message}"
    rescue Faraday::ConnectionFailed => e
      log_error("embedding_network_error")
      raise NetworkError, "Embedding connection failed: #{e.message}"
    rescue Faraday::ClientError => e
      handle_faraday_error(e)
    rescue Faraday::ServerError => e
      handle_faraday_error(e)
    rescue OpenAI::Error => e
      handle_openai_error(e)
    rescue StandardError => e
      log_error("embedding_unexpected_error")
      raise APIError, "Embedding error: #{e.message}"
    end

    # Generate embeddings for multiple texts in batch
    # @param texts [Array<String>] The texts to embed
    # @param model [String] The embedding model to use
    # @return [Array<Array<Float>>] Array of embedding vectors
    def embed_batch(texts, model: nil)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      embedding_model = model || "text-embedding-3-small"

      response = @openai_client.embeddings(
        parameters: {
          model: embedding_model,
          input: texts
        }
      )

      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      embeddings = response.dig("data")&.sort_by { |d| d["index"] }&.map { |d| d["embedding"] }
      total_tokens = response.dig("usage", "total_tokens")

      log_embedding_success(embedding_model, duration, total_tokens, embeddings&.first&.length)
      embeddings
    rescue Faraday::TimeoutError => e
      log_error("embedding_batch_timeout")
      raise TimeoutError, "Embedding batch request timed out: #{e.message}"
    rescue Faraday::ConnectionFailed => e
      log_error("embedding_batch_network_error")
      raise NetworkError, "Embedding batch connection failed: #{e.message}"
    rescue Faraday::ClientError => e
      handle_faraday_error(e)
    rescue Faraday::ServerError => e
      handle_faraday_error(e)
    rescue OpenAI::Error => e
      handle_openai_error(e)
    rescue StandardError => e
      log_error("embedding_batch_unexpected_error")
      raise APIError, "Embedding batch error: #{e.message}"
    end

    private

    def validate_config!
      if @config.openai_api_key.blank?
        raise ConfigurationError, "API key is missing. Set OPENAI_API_KEY in your .env file."
      end
    end

    def build_client
      options = {
        access_token: @config.openai_api_key,
        request_timeout: @config.timeout,
        log_errors: Rails.env.development?
      }
      options[:uri_base] = @config.api_base_url if @config.api_base_url
      OpenAI::Client.new(**options)
    end

    def build_parameters(messages, model, temperature, max_tokens, options)
      {
        model: model || @config.default_model,
        messages: messages,
        temperature: temperature || @config.default_temperature,
        max_tokens: max_tokens || @config.max_tokens
      }.merge(options)
    end

    def build_response(response)
      choice = response.dig("choices", 0)
      AI::ChatResponse.new(
        content: choice.dig("message", "content"),
        model: response["model"],
        usage: {
          prompt_tokens: response.dig("usage", "prompt_tokens"),
          completion_tokens: response.dig("usage", "completion_tokens"),
          total_tokens: response.dig("usage", "total_tokens")
        }
      )
    end

    def handle_faraday_error(error)
      status = error.response_status
      body = error.response_body
      message = extract_error_message(body) || error.message

      if status == 401
        log_error("authentication_error")
        raise AuthenticationError, message
      elsif status == 429
        log_error("rate_limit")
        raise RateLimitError, message
      else
        log_error("api_error")
        raise APIError, message
      end
    end

    def handle_openai_error(error)
      error_message = error.message.downcase
      if error_message.include?("401") || error_message.include?("unauthorized") || error_message.include?("authentication") || error_message.include?("incorrect api key")
        log_error("authentication_error")
        raise AuthenticationError, error.message
      elsif error_message.include?("429") || error_message.include?("rate limit")
        log_error("rate_limit")
        raise RateLimitError, error.message
      else
        log_error("api_error")
        raise APIError, error.message
      end
    end

    def extract_error_message(body)
      return nil if body.blank?

      if body.is_a?(Hash)
        body.dig("error", "message") || body["message"]
      elsif body.is_a?(String)
        parsed = JSON.parse(body) rescue nil
        parsed&.dig("error", "message") || parsed&.[]("message") || body
      end
    end

    def log_error(error_type)
      Rails.logger.error("[AI::Client] Error=#{error_type}")
    end

    def log_success(model, duration, tokens)
      Rails.logger.info("[AI::Client] Model=#{model} Duration=#{duration.round(3)}s Tokens=#{tokens}")
    end

    def log_embedding_success(model, duration, tokens, dimensions)
      Rails.logger.info("[AI::Client] Embedding Model=#{model} Duration=#{duration.round(3)}s Tokens=#{tokens} Dimensions=#{dimensions}")
    end
  end
end

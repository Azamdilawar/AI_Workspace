module KnowledgeBase
  class EmbeddingService
    attr_reader :knowledge, :client, :chunking_service

    def initialize(knowledge, client: nil)
      @knowledge = knowledge
      @client = client || AI::Client.new
      @chunking_service = Document::ChunkingService.new(
        strategy: :recursive,
        max_tokens: 500,
        overlap_percentage: 0.1
      )
    end

    # Process a knowledge document: chunk it and generate embeddings
    # @return [Hash] Summary of the processing
    def process
      validate_knowledge!

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # Step 1: Chunk the document
      chunks = chunk_document
      return { success: false, error: "No chunks generated", chunks_count: 0 } if chunks.empty?

      # Step 2: Create KnowledgeChunk records
      knowledge_chunks = create_chunks(chunks)

      # Step 3: Generate embeddings in batch
      embeddings = generate_embeddings(knowledge_chunks)

      # Step 4: Store embeddings
      store_embeddings(knowledge_chunks, embeddings)

      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      log_success(knowledge_chunks.length, duration)

      {
        success: true,
        chunks_count: knowledge_chunks.length,
        embeddings_count: embeddings.length,
        duration: duration.round(3)
      }
    rescue StandardError => e
      log_error(e)
      { success: false, error: e.message, chunks_count: 0 }
    end

    # Process only chunks that don't have embeddings yet
    # @return [Hash] Summary of the processing
    def process_pending
      validate_knowledge!

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # Find chunks without embeddings
      pending_chunks = knowledge.knowledge_chunks.pending_embedding

      if pending_chunks.empty?
        return { success: true, message: "No pending chunks", chunks_count: 0, embeddings_count: 0 }
      end

      # Generate embeddings for pending chunks
      embeddings = generate_embeddings(pending_chunks)

      # Store embeddings
      store_embeddings(pending_chunks, embeddings)

      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      log_success(pending_chunks.length, duration)

      {
        success: true,
        chunks_count: pending_chunks.length,
        embeddings_count: embeddings.length,
        duration: duration.round(3)
      }
    rescue StandardError => e
      log_error(e)
      { success: false, error: e.message, chunks_count: 0 }
    end

    private

    def validate_knowledge!
      raise ArgumentError, "Knowledge must be a Knowledge record" unless knowledge.is_a?(Knowledge)
      raise ArgumentError, "Knowledge content is blank" if knowledge.content.blank?
    end

    def chunk_document
      chunking_service.chunk(knowledge.content)
    end

    def create_chunks(chunks_data)
      knowledge_chunks = []

      chunks_data.each do |chunk_data|
        chunk = knowledge.knowledge_chunks.create!(
          content: chunk_data[:content],
          position: chunk_data[:position],
          metadata: chunk_data[:metadata]
        )
        knowledge_chunks << chunk
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error("[KnowledgeBase::EmbeddingService] Failed to create chunk: #{e.message}")
        next
      end

      knowledge_chunks
    end

    def generate_embeddings(knowledge_chunks)
      texts = knowledge_chunks.map(&:content)

      # Use batch embedding for efficiency (up to 2048 texts per API call)
      # For very large batches, we could chunk the batches too
      client.embed_batch(texts)
    rescue AI::RateLimitError => e
      Rails.logger.warn("[KnowledgeBase::EmbeddingService] Rate limit hit, retrying with single embeddings...")
      generate_embeddings_individually(knowledge_chunks)
    end

    def generate_embeddings_individually(knowledge_chunks)
      embeddings = []

      knowledge_chunks.each do |chunk|
        embedding = client.embed(chunk.content)
        embeddings << embedding

        # Small delay to avoid rate limiting
        sleep(0.1)
      rescue AI::RateLimitError => e
        Rails.logger.error("[KnowledgeBase::EmbeddingService] Rate limit hit for chunk #{chunk.id}: #{e.message}")
        embeddings << nil
      rescue AI::APIError => e
        Rails.logger.error("[KnowledgeBase::EmbeddingService] API error for chunk #{chunk.id}: #{e.message}")
        embeddings << nil
      end

      embeddings
    end

    def store_embeddings(knowledge_chunks, embeddings)
      knowledge_chunks.each_with_index do |chunk, index|
        embedding = embeddings[index]
        next if embedding.nil?

        chunk.update!(embedding: embedding.to_s)
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error("[KnowledgeBase::EmbeddingService] Failed to store embedding for chunk #{chunk.id}: #{e.message}")
      end
    end

    def log_success(chunks_count, duration)
      Rails.logger.info(
        "[KnowledgeBase::EmbeddingService] Knowledge=#{knowledge.id} " \
        "Chunks=#{chunks_count} Duration=#{duration.round(3)}s"
      )
    end

    def log_error(error)
      knowledge_id = knowledge.respond_to?(:id) ? knowledge.id : "unknown"
      Rails.logger.error(
        "[KnowledgeBase::EmbeddingService] Knowledge=#{knowledge_id} Error=#{error.class}: #{error.message}"
      )
    end
  end
end

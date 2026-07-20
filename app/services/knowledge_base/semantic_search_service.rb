module KnowledgeBase
  class SemanticSearchService
    def initialize(client: nil, limit: 5)
      @client = client || AI::Client.new
      @limit = limit
    end

    def search(query)
      raise ArgumentError, "Query cannot be blank" if query.nil? || query.strip.empty?

      # Step 1: Embed the query
      query_embedding = @client.embed(query)

      # Step 2: Search for similar chunks
      chunks = KnowledgeChunk.similar_to(query_embedding, limit: @limit)

      # Step 3: Format results
      chunks.map do |chunk|
        {
          id: chunk.id,
          content: chunk.content,
          position: chunk.position,
          knowledge_id: chunk.knowledge_id,
          knowledge_title: chunk.knowledge.title,
          metadata: chunk.metadata
        }
      end
    rescue AI::Error => e
      Rails.logger.error "[SemanticSearchService] AI Error: #{e.message}"
      { error: e.message }
    rescue ArgumentError
      raise
    rescue StandardError => e
      Rails.logger.error "[SemanticSearchService] Error: #{e.message}"
      { error: e.message }
    end
  end
end

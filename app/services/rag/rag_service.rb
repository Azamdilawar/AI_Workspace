module Rag
  class RagService
    def initialize(client: nil, search_limit: 5, system_prompt: nil, response_format: :none)
      @client = client || AI::Client.new
      @search_limit = search_limit
      @prompt_builder = PromptBuilder.new(system_prompt: system_prompt)
      @search_service = KnowledgeBase::SemanticSearchService.new(client: @client, limit: @search_limit)
      @response_formatter = ResponseFormatter.new(format: response_format)
    end

    def search(question)
      raise ArgumentError, "Question cannot be blank" if question.nil? || question.strip.empty?

      # Step 1: Retrieve relevant chunks
      chunks = @search_service.search(question)
      return { error: "No relevant information found in the knowledge base" } if chunks.is_a?(Hash) && chunks[:error]
      return { error: "No relevant information found in the knowledge base" } if chunks.is_a?(Array) && chunks.empty?

      # Step 2: Build prompt
      prompt = @prompt_builder.build(question, chunks)

      # Step 3: Generate answer
      response = @client.chat([
        { role: "system", content: prompt[:system] },
        { role: "user", content: prompt[:user] }
      ])

      # Step 4: Format response
      sources = format_sources(chunks)
      formatted_answer = @response_formatter.format(response.content, sources)

      {
        answer: formatted_answer,
        raw_answer: response.content,
        sources: sources,
        metadata: {
          question: question,
          chunks_used: chunks.length,
          model: response.model,
          prompt_tokens: prompt[:metadata][:estimated_tokens]
        }
      }
    rescue ArgumentError
      raise
    rescue AI::Error => e
      Rails.logger.error "[RagService] AI Error: #{e.message}"
      { error: e.message }
    rescue StandardError => e
      Rails.logger.error "[RagService] Error: #{e.message}"
      { error: e.message }
    end

    private

    def format_sources(chunks)
      chunks.map.with_index do |chunk, index|
        {
          number: index + 1,
          title: chunk[:knowledge_title],
          position: chunk[:position],
          content: chunk[:content]
        }
      end
    end
  end
end

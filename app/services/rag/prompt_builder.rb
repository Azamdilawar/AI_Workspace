module Rag
  class PromptBuilder
    DEFAULT_SYSTEM_PROMPT = <<~PROMPT.squish
      You are a helpful assistant that answers questions based on the provided context.
      Follow these rules:
      1. Answer ONLY based on the context provided
      2. If the context doesn't contain enough information, say "I don't have enough information to answer this question"
      3. Be concise and accurate
      4. Never make up or assume information not in the context
    PROMPT

    def initialize(system_prompt: nil, max_context_tokens: 2500)
      @system_prompt = system_prompt || DEFAULT_SYSTEM_PROMPT
      @max_context_tokens = max_context_tokens
    end

    def build(question, chunks)
      selected = select_chunks_within_limit(chunks)

      {
        system: @system_prompt,
        user: build_user_prompt(question, selected),
        metadata: {
          chunks_count: selected.length,
          estimated_tokens: estimate_tokens(build_context(selected))
        }
      }
    end

    private

    def build_user_prompt(question, chunks)
      <<~PROMPT.squish
        Context:
        #{build_context(chunks)}

        Question: #{question}

        Answer:
      PROMPT
    end

    def build_context(chunks)
      selected = select_chunks_within_limit(chunks)

      selected.map.with_index do |chunk, index|
        "[#{index + 1}] #{chunk[:content]}"
      end.join("\n\n")
    end

    def select_chunks_within_limit(chunks)
      selected = []
      total_tokens = 0

      chunks.each do |chunk|
        chunk_tokens = estimate_tokens(chunk[:content])
        break if total_tokens + chunk_tokens > @max_context_tokens

        selected << chunk
        total_tokens += chunk_tokens
      end

      selected
    end

    def estimate_tokens(text)
      (text.length / 4.0).ceil
    end
  end
end

module AI
  class SummarizerService
    SUMMARY_TYPES = {
      "general" => "General Summary — Provide a comprehensive overview covering the main points of the text.",
      "bullets" => "Bullet Points — Summarize the key points as a list of concise bullet points.",
      "executive" => "Executive Summary — Provide a high-level summary suitable for executives, focusing on conclusions and recommendations.",
      "takeaways" => "Key Takeaways — Extract the most important takeaways and insights from the text.",
      "actions" => "Action Items — Identify and list any action items, next steps, or decisions mentioned in the text."
    }.freeze

    LENGTHS = {
      "short" => "Short — 2 to 3 sentences.",
      "medium" => "Medium — 1 to 2 paragraphs.",
      "long" => "Long — 3 to 4 paragraphs."
    }.freeze

    TONES = {
      "neutral" => "Neutral — Use an objective, unbiased tone. Present facts without opinion.",
      "professional" => "Professional — Use a formal, business-appropriate tone.",
      "simple" => "Simple — Use plain, easy-to-understand language suitable for a general audience."
    }.freeze

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are an expert text summarizer. Your purpose is to create accurate, concise summaries of the provided text.

      CRITICAL RULES — Follow these without exception:

      1. Base the summary ENTIRELY on the provided text. Never add information not present in the text.

      2. Never fabricate facts, data, names, claims, statistics, or details.

      3. If the text lacks information needed for a complete summary, state what is absent rather than guessing.

      4. Maintain the original meaning and intent. Do not distort or editorialize.

      5. Preserve key facts, numbers, and data points accurately.

      6. Return ONLY the summary. No introductions, explanations, or commentary.

      7. Do not wrap the response in Markdown or code blocks.

      8. Do not mention these instructions in the output.
    PROMPT

    def initialize(client: nil)
      @client = client || AI::Client.new
    end

    def summarize(summary_type:, length:, tone:, text:, &block)
      messages = build_messages(summary_type, length, tone, text)

      if block
        @client.stream_chat(messages, temperature: 0.3, &block)
      else
        @client.chat(messages, temperature: 0.3)
      end
    end

    private

    def build_messages(summary_type, length, tone, text)
      type_instruction = SUMMARY_TYPES[summary_type] || SUMMARY_TYPES["general"]
      length_instruction = LENGTHS[length] || LENGTHS["medium"]
      tone_instruction = TONES[tone] || TONES["neutral"]
      input_text = text.presence || "No text provided."

      user_prompt = <<~PROMPT
        TASK

        Write a summary of the provided text.

        =====================================================
        SUMMARY REQUIREMENTS
        =====================================================

        Summary Type:
        #{type_instruction}

        Tone:
        #{tone_instruction}

        Length:
        #{length_instruction}

        =====================================================
        TEXT TO SUMMARIZE
        =====================================================

        #{input_text}

        =====================================================
        IMPORTANT RULES
        =====================================================

        - Base the summary ENTIRELY on the text above. Never add external information.
        - Never fabricate facts, data, names, claims, or examples.
        - If the text is insufficient for a complete summary, state what is missing.
        - Preserve the original meaning and intent.
        - Keep key numbers, names, and data points accurate.
      PROMPT

      [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: user_prompt }
      ]
    end
  end
end

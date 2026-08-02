module Rag
  class ResponseFormatter
    FORMATS = {
      none: :format_none,
      footer: :format_footer,
      inline: :format_inline,
      detailed: :format_detailed
    }

    def initialize(format: :footer)
      @format = format
      raise ArgumentError, "Invalid format: #{format}" unless FORMATS.key?(format)
    end

    def format(answer, sources)
      return answer if @format == :none

      send(FORMATS[@format], answer, sources)
    end

    private

    def format_none(answer, _sources)
      answer
    end

    def format_footer(answer, sources)
      <<~RESPONSE.squish
        #{answer}

        ---
        #{format_sources_list(sources)}
      RESPONSE
    end

    def format_inline(answer, sources)
      # Find references in answer like [1], [2] and link them
      formatted = answer.dup

      sources.each do |source|
        # Replace [N] with source reference if present
        formatted = formatted.gsub(/\[#{source[:number]}\]/, "[#{source[:number]}: #{source[:title]}]")
      end

      # If no inline references found, append footer
      if formatted == answer
        format_footer(answer, sources)
      else
        formatted
      end
    end

    def format_detailed(answer, sources)
      <<~RESPONSE.squish
        #{answer}

        ---
        #{format_sources_detailed(sources)}
      RESPONSE
    end

    def format_sources_list(sources)
      "Sources:\n" + sources.map do |source|
        "[#{source[:number]}] #{source[:title]} (Chunk #{source[:position]})"
      end.join("\n")
    end

    def format_sources_detailed(sources)
      sources.map do |source|
        <<~SOURCE
          [#{source[:number]}] #{source[:title]} (Chunk #{source[:position]})
          "#{source[:content]}"
        SOURCE
      end.join("\n")
    end
  end
end

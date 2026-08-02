module Document
  class ChunkingService
    # Default configuration
    DEFAULT_MAX_TOKENS = 500
    DEFAULT_OVERLAP_PERCENTAGE = 0.1
    CHARS_PER_TOKEN = 4  # Approximate: 1 token ≈ 4 characters

    attr_reader :strategy, :max_tokens, :overlap_percentage

    def initialize(strategy: :recursive, max_tokens: DEFAULT_MAX_TOKENS, overlap_percentage: DEFAULT_OVERLAP_PERCENTAGE)
      @strategy = strategy
      @max_tokens = max_tokens
      @overlap_percentage = overlap_percentage
    end

    # Main method to chunk text content
    # Returns an array of hashes with :content, :position, and :metadata
    def chunk(content)
      return [] if content.blank?

      chunks = case strategy.to_sym
               when :fixed
                 fixed_size_chunking(content)
               when :sentence
                 sentence_chunking(content)
               when :paragraph
                 paragraph_chunking(content)
               when :recursive
                 recursive_chunking(content)
               else
                 raise ArgumentError, "Unknown strategy: #{strategy}"
               end

      add_positions(chunks)
    end

    private

    # Strategy 1: Fixed-size chunking
    # Splits text into chunks of approximately max_tokens tokens
    def fixed_size_chunking(content)
      max_chars = max_tokens * CHARS_PER_TOKEN
      overlap_chars = (max_chars * overlap_percentage).to_i
      chunks = []
      start = 0

      while start < content.length
        chunk_end = [start + max_chars, content.length].min
        chunk_content = content[start...chunk_end]

        # Try to break at a sentence boundary if possible
        if chunk_end < content.length
          last_period = chunk_content.rindex('.')
          if last_period && last_period > max_chars * 0.5
            chunk_content = content[start...(start + last_period + 1)]
            chunk_end = start + last_period + 1
          end
        end

        chunks << { content: chunk_content.strip, metadata: {} }

        # Move start forward with overlap
        if overlap_chars > 0 && chunk_end < content.length
          start = chunk_end - overlap_chars
        else
          start = chunk_end
        end
      end

      chunks
    end

    # Strategy 2: Sentence-based chunking
    # Splits by sentences, then combines into chunks of max_tokens
    def sentence_chunking(content)
      sentences = split_into_sentences(content)
      chunks = []
      current_chunk = []
      current_tokens = 0

      sentences.each do |sentence|
        sentence_tokens = estimate_tokens(sentence)

        if current_tokens + sentence_tokens > max_tokens && current_chunk.any?
          chunks << { content: current_chunk.join(' ').strip, metadata: {} }
          # Start new chunk with overlap (last sentence)
          current_chunk = [current_chunk.last].compact
          current_tokens = estimate_tokens(current_chunk.join(' '))
        end

        current_chunk << sentence
        current_tokens += sentence_tokens
      end

      chunks << { content: current_chunk.join(' ').strip, metadata: {} } if current_chunk.any?
      chunks
    end

    # Strategy 3: Paragraph-based chunking
    # Splits by double newlines (paragraphs), then combines into chunks
    def paragraph_chunking(content)
      paragraphs = content.split(/\n\n+/).reject(&:blank?)
      chunks = []
      current_chunk = []
      current_tokens = 0

      paragraphs.each do |paragraph|
        paragraph_tokens = estimate_tokens(paragraph)

        if current_tokens + paragraph_tokens > max_tokens && current_chunk.any?
          chunks << { content: current_chunk.join("\n\n").strip, metadata: {} }
          current_chunk = []
          current_tokens = 0
        end

        # If a single paragraph exceeds max_tokens, split it further
        if paragraph_tokens > max_tokens
          if current_chunk.any?
            chunks << { content: current_chunk.join("\n\n").strip, metadata: {} }
            current_chunk = []
            current_tokens = 0
          end
          # Try sentence chunking first, then fall back to fixed-size
          sentence_chunks = sentence_chunking(paragraph)
          if sentence_chunks.length > 1
            chunks.concat(sentence_chunks)
          else
            chunks.concat(fixed_size_chunking(paragraph))
          end
        else
          current_chunk << paragraph
          current_tokens += paragraph_tokens
        end
      end

      chunks << { content: current_chunk.join("\n\n").strip, metadata: {} } if current_chunk.any?
      chunks
    end

    # Strategy 4: Recursive chunking (best practice)
    # Tries paragraph splitting first, then sentence, then fixed-size
    def recursive_chunking(content)
      # First, try to split by paragraphs
      paragraphs = content.split(/\n\n+/).reject(&:blank?)

      # If we have multiple paragraphs, use paragraph-based chunking
      if paragraphs.length > 1
        paragraph_chunking(content)
      else
        # If single paragraph (or no paragraphs), try sentence splitting
        sentences = split_into_sentences(content)

        if sentences.length > 1
          sentence_chunking(content)
        else
          # If single sentence (or no sentences), use fixed-size chunking
          fixed_size_chunking(content)
        end
      end
    end

    # Helper: Split text into sentences
    def split_into_sentences(content)
      # Split on sentence boundaries (period, exclamation, question mark)
      # But not on abbreviations like "Dr." or "Mr."
      content.split(/(?<=[.!?])\s+/).reject(&:blank?)
    end

    # Helper: Estimate token count (approximate)
    def estimate_tokens(text)
      return 0 if text.blank?
      (text.length / CHARS_PER_TOKEN.to_f).ceil
    end

    # Helper: Add position numbers to chunks
    def add_positions(chunks)
      chunks.each_with_index.map do |chunk, index|
        chunk.merge(position: index + 1)
      end
    end
  end
end

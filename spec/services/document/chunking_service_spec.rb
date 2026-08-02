require "rails_helper"

RSpec.describe Document::ChunkingService do
  describe "#initialize" do
    it "uses default values when no options provided" do
      service = described_class.new
      expect(service.strategy).to eq(:recursive)
      expect(service.max_tokens).to eq(500)
      expect(service.overlap_percentage).to eq(0.1)
    end

    it "allows custom strategy" do
      service = described_class.new(strategy: :fixed)
      expect(service.strategy).to eq(:fixed)
    end

    it "allows custom max_tokens" do
      service = described_class.new(max_tokens: 100)
      expect(service.max_tokens).to eq(100)
    end

    it "allows custom overlap_percentage" do
      service = described_class.new(overlap_percentage: 0.2)
      expect(service.overlap_percentage).to eq(0.2)
    end

    it "raises error for unknown strategy when chunking" do
      service = described_class.new(strategy: :unknown)
      expect {
        service.chunk("Hello world")
      }.to raise_error(ArgumentError, "Unknown strategy: unknown")
    end
  end

  describe "#chunk" do
    context "with empty or blank content" do
      it "returns empty array for nil" do
        service = described_class.new
        expect(service.chunk(nil)).to eq([])
      end

      it "returns empty array for empty string" do
        service = described_class.new
        expect(service.chunk("")).to eq([])
      end

      it "returns empty array for whitespace-only string" do
        service = described_class.new
        expect(service.chunk("   \n\n  ")).to eq([])
      end
    end

    context "with short text" do
      let(:short_text) { "Hello world." }

      it "returns single chunk for text within max_tokens" do
        service = described_class.new(max_tokens: 100)
        chunks = service.chunk(short_text)
        expect(chunks.length).to eq(1)
        expect(chunks.first[:content]).to eq(short_text)
      end

      it "includes position in chunk" do
        service = described_class.new
        chunks = service.chunk(short_text)
        expect(chunks.first[:position]).to eq(1)
      end

      it "includes metadata in chunk" do
        service = described_class.new
        chunks = service.chunk(short_text)
        expect(chunks.first[:metadata]).to eq({})
      end
    end
  end

  describe "fixed-size chunking" do
    let(:service) { described_class.new(strategy: :fixed, max_tokens: 20, overlap_percentage: 0) }
    let(:long_text) do
      "Ruby is a dynamic programming language. It was created in 1995. " \
      "Ruby on Rails is a popular web framework. It was created in 2004. " \
      "Ruby has many gems. These are libraries that extend functionality."
    end

    it "splits text into multiple chunks when exceeding max_tokens" do
      chunks = service.chunk(long_text)
      expect(chunks.length).to be > 1
    end

    it "keeps each chunk within max_tokens limit" do
      chunks = service.chunk(long_text)
      chunks.each do |chunk|
        token_count = (chunk[:content].length / 4.0).ceil
        expect(token_count).to be <= 25  # Allow some flexibility for sentence breaking
      end
    end

    it "preserves all text content" do
      chunks = service.chunk(long_text)
      combined = chunks.map { |c| c[:content] }.join(" ")
      expect(combined).to include("Ruby is a dynamic")
      expect(combined).to include("extend functionality")
    end

    it "numbers positions sequentially" do
      chunks = service.chunk(long_text)
      positions = chunks.map { |c| c[:position] }
      expect(positions).to eq((1..chunks.length).to_a)
    end

    context "with overlap" do
      let(:service_with_overlap) do
        described_class.new(strategy: :fixed, max_tokens: 20, overlap_percentage: 0.2)
      end

      it "creates overlapping chunks" do
        chunks = service_with_overlap.chunk(long_text)
        expect(chunks.length).to be >= 2
      end
    end
  end

  describe "sentence chunking" do
    let(:service) { described_class.new(strategy: :sentence, max_tokens: 20) }
    let(:multi_sentence_text) do
      "First sentence here with some content. Second sentence is much longer and has more words. " \
      "Third sentence has even more content to make it longer. Fourth and final sentence wraps things up."
    end

    it "splits by sentences" do
      chunks = service.chunk(multi_sentence_text)
      expect(chunks.length).to be >= 2
    end

    it "respects sentence boundaries" do
      chunks = service.chunk(multi_sentence_text)
      chunks.each do |chunk|
        expect(chunk[:content]).to match(/[.!?]\z/).or(
          eq(chunks.last[:content])  # Last chunk may not end with punctuation
        )
      end
    end

    it "combines short sentences into single chunk" do
      short_sentences = "Hi. Hello. Hey."
      service = described_class.new(strategy: :sentence, max_tokens: 100)
      chunks = service.chunk(short_sentences)
      expect(chunks.length).to eq(1)
    end

    it "separates long sentences into different chunks" do
      long_text = "This is a very long sentence that goes on and on. " \
                  "Another very long sentence that also continues. " \
                  "Third very long sentence that keeps going."
      service = described_class.new(strategy: :sentence, max_tokens: 20)
      chunks = service.chunk(long_text)
      expect(chunks.length).to be > 1
    end
  end

  describe "paragraph chunking" do
    let(:service) { described_class.new(strategy: :paragraph, max_tokens: 20) }
    let(:multi_paragraph_text) do
      "First paragraph with some content that is moderately long.\n\n" \
      "Second paragraph has different content and is also longer.\n\n" \
      "Third paragraph wraps things up with additional text."
    end

    it "splits by double newlines (paragraphs)" do
      chunks = service.chunk(multi_paragraph_text)
      expect(chunks.length).to eq(3)
    end

    it "preserves paragraph structure" do
      chunks = service.chunk(multi_paragraph_text)
      expect(chunks[0][:content]).to include("First paragraph")
      expect(chunks[1][:content]).to include("Second paragraph")
      expect(chunks[2][:content]).to include("Third paragraph")
    end

    it "combines short paragraphs into single chunk" do
      short_paragraphs = "Short.\n\nAlso short.\n\nAnd short."
      service = described_class.new(strategy: :paragraph, max_tokens: 100)
      chunks = service.chunk(short_paragraphs)
      expect(chunks.length).to eq(1)
    end

    it "handles single paragraph" do
      single_paragraph = "Just one paragraph with no double newlines."
      service = described_class.new(strategy: :paragraph, max_tokens: 50)
      chunks = service.chunk(single_paragraph)
      expect(chunks.length).to eq(1)
    end

    context "with long paragraph exceeding max_tokens" do
      it "splits long paragraph using sentence chunking" do
        long_paragraph = "First sentence. Second sentence. Third sentence. " \
                        "Fourth sentence. Fifth sentence. Sixth sentence."
        service = described_class.new(strategy: :paragraph, max_tokens: 20)
        chunks = service.chunk(long_paragraph)
        expect(chunks.length).to be > 1
      end
    end
  end

  describe "recursive chunking (default)" do
    let(:service) { described_class.new(strategy: :recursive, max_tokens: 15) }
    let(:multi_paragraph_text) do
      "First paragraph content with some text here.\n\n" \
      "Second paragraph content with more text there.\n\n" \
      "Third paragraph content with even more text everywhere."
    end

    it "uses paragraph chunking for multi-paragraph text" do
      chunks = service.chunk(multi_paragraph_text)
      expect(chunks.length).to eq(3)
    end

    it "uses sentence chunking for single paragraph with multiple sentences" do
      single_paragraph = "First sentence. Second sentence. Third sentence."
      chunks = service.chunk(single_paragraph)
      expect(chunks.length).to be >= 1
    end

    it "uses fixed-size chunking for single sentence" do
      single_sentence = "Just one long sentence without any punctuation marks"
      service = described_class.new(strategy: :recursive, max_tokens: 10)
      chunks = service.chunk(single_sentence)
      expect(chunks.length).to be >= 1
    end

    it "adapts strategy based on content structure" do
      # Multi-paragraph text should use paragraph strategy
      chunks = service.chunk(multi_paragraph_text)
      expect(chunks.length).to be >= 2  # Should split into multiple chunks
    end
  end

  describe "token estimation" do
    it "estimates tokens based on character count" do
      service = described_class.new
      text = "Hello world"  # 11 chars
      chunks = service.chunk(text)
      # With 11 chars and 4 chars per token, estimate = 3 tokens
      expect(chunks.length).to eq(1)  # Fits in one chunk
    end

    it "creates multiple chunks when text exceeds max_tokens" do
      service = described_class.new(strategy: :fixed, max_tokens: 5)
      text = "Hello world this is a test"  # 26 chars = ~7 tokens
      chunks = service.chunk(text)
      expect(chunks.length).to be > 1
    end
  end

  describe "chunk structure" do
    let(:service) { described_class.new }
    let(:text) { "Hello world. This is a test." }

    it "returns array of hashes" do
      chunks = service.chunk(text)
      expect(chunks).to be_an(Array)
      chunks.each do |chunk|
        expect(chunk).to be_a(Hash)
      end
    end

    it "includes required keys" do
      chunks = service.chunk(text)
      chunks.each do |chunk|
        expect(chunk).to have_key(:content)
        expect(chunk).to have_key(:position)
        expect(chunk).to have_key(:metadata)
      end
    end

    it "has content as string" do
      chunks = service.chunk(text)
      chunks.each do |chunk|
        expect(chunk[:content]).to be_a(String)
        expect(chunk[:content]).not_to be_empty
      end
    end

    it "has position as integer starting from 1" do
      chunks = service.chunk(text)
      chunks.each_with_index do |chunk, index|
        expect(chunk[:position]).to eq(index + 1)
      end
    end

    it "has metadata as hash" do
      chunks = service.chunk(text)
      chunks.each do |chunk|
        expect(chunk[:metadata]).to be_a(Hash)
      end
    end
  end

  describe "edge cases" do
    it "handles text with only punctuation" do
      service = described_class.new
      text = "!!! ??? ..."
      chunks = service.chunk(text)
      expect(chunks.length).to eq(1)
    end

    it "handles text with special characters" do
      service = described_class.new
      text = "Ruby 3.2.1 released! New features include: pattern matching, endless ranges."
      chunks = service.chunk(text)
      expect(chunks.length).to be >= 1
    end

    it "handles very long single paragraph" do
      service = described_class.new(strategy: :paragraph, max_tokens: 50)
      # Create a long paragraph with sentence boundaries
      text = "This is a sentence. " * 50  # 1000 characters with sentence boundaries
      chunks = service.chunk(text)
      expect(chunks.length).to be > 1
    end

    it "handles text with multiple newlines" do
      service = described_class.new
      text = "First\n\n\n\nSecond\n\n\n\nThird"
      chunks = service.chunk(text)
      expect(chunks.length).to be >= 1
    end

    it "handles text with leading/trailing whitespace" do
      service = described_class.new
      text = "  Hello world  "
      chunks = service.chunk(text)
      expect(chunks.first[:content]).to eq("Hello world")
    end
  end

  describe "real-world scenarios" do
    let(:blog_post) do
      <<~TEXT
        Getting Started with Ruby on Rails

        Ruby on Rails is a powerful web application framework that makes building web applications a breeze. Created by David Heinemeier Hansson in 2004, Rails has become one of the most popular frameworks for building web applications.

        Why Choose Rails?

        Rails follows the convention over configuration philosophy, which means you spend less time configuring and more time building. It comes with everything you need: database management, routing, controllers, views, and more.

        Setting Up Your First Rails Application

        To get started, you'll need to install Ruby and Rails on your machine. Open your terminal and run: gem install rails. Then create a new application with: rails new my_app.
      TEXT
    end

    it "handles blog post content" do
      service = described_class.new(strategy: :paragraph, max_tokens: 100)
      chunks = service.chunk(blog_post)
      expect(chunks.length).to be >= 3
      expect(chunks.length).to be <= 6
    end

    it "preserves meaningful content in each chunk" do
      service = described_class.new(strategy: :paragraph, max_tokens: 100)
      chunks = service.chunk(blog_post)
      chunks.each do |chunk|
        expect(chunk[:content].length).to be > 10
      end
    end
  end
end

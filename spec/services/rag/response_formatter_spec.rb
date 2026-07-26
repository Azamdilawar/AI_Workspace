require 'rails_helper'

RSpec.describe Rag::ResponseFormatter do
  let(:answer) { "Ruby is a dynamic programming language." }
  let(:sources) do
    [
      { number: 1, title: "Ruby Basics", position: 1, content: "Ruby is a language." },
      { number: 2, title: "Ruby History", position: 2, content: "Ruby was created in 1995." }
    ]
  end

  describe "#initialize" do
    it "creates formatter with default format" do
      formatter = described_class.new
      expect(formatter).to be_a(described_class)
    end

    it "creates formatter with footer format" do
      formatter = described_class.new(format: :footer)
      expect(formatter).to be_a(described_class)
    end

    it "creates formatter with none format" do
      formatter = described_class.new(format: :none)
      expect(formatter).to be_a(described_class)
    end

    it "raises error for invalid format" do
      expect { described_class.new(format: :invalid) }.to raise_error(ArgumentError, /Invalid format/)
    end
  end

  describe "#format" do
    context "with format: :none" do
      let(:formatter) { described_class.new(format: :none) }

      it "returns answer without sources" do
        result = formatter.format(answer, sources)
        expect(result).to eq(answer)
        expect(result).not_to include("---")
        expect(result).not_to include("[1]")
      end
    end

    context "with format: :footer" do
      let(:formatter) { described_class.new(format: :footer) }

      it "appends sources at bottom" do
        result = formatter.format(answer, sources)
        expect(result).to include(answer)
        expect(result).to include("---")
      end

      it "includes all sources" do
        result = formatter.format(answer, sources)
        expect(result).to include("[1] Ruby Basics (Chunk 1)")
        expect(result).to include("[2] Ruby History (Chunk 2)")
      end

      it "formats sources as list" do
        result = formatter.format(answer, sources)
        expect(result).to include("Sources:")
      end
    end

    context "with format: :inline" do
      let(:formatter) { described_class.new(format: :inline) }

      it "expands inline references" do
        answer_with_refs = "Ruby [1] is a language [2]."
        result = formatter.format(answer_with_refs, sources)
        expect(result).to include("[1: Ruby Basics]")
        expect(result).to include("[2: Ruby History]")
      end

      it "falls back to footer if no references found" do
        result = formatter.format(answer, sources)
        expect(result).to include("---")
        expect(result).to include("[1] Ruby Basics")
      end
    end

    context "with format: :detailed" do
      let(:formatter) { described_class.new(format: :detailed) }

      it "includes full content snippets" do
        result = formatter.format(answer, sources)
        expect(result).to include('"Ruby is a language."')
        expect(result).to include('"Ruby was created in 1995."')
      end

      it "includes source metadata" do
        result = formatter.format(answer, sources)
        expect(result).to include("[1] Ruby Basics (Chunk 1)")
        expect(result).to include("[2] Ruby History (Chunk 2)")
      end
    end

    context "with empty sources" do
      let(:formatter) { described_class.new(format: :footer) }

      it "handles empty sources array" do
        result = formatter.format(answer, [])
        expect(result).to include(answer)
        expect(result).to include("---")
      end
    end
  end
end

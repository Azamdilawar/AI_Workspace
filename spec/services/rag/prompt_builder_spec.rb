require 'rails_helper'

RSpec.describe Rag::PromptBuilder do
  let(:builder) { described_class.new }
  let(:question) { "What is Ruby?" }
  let(:chunks) do
    [
      { id: 1, content: "Ruby is a dynamic programming language.", position: 1, knowledge_title: "Ruby Basics" },
      { id: 2, content: "Ruby was created in 1995.", position: 2, knowledge_title: "Ruby History" },
      { id: 3, content: "Ruby on Rails is a web framework.", position: 3, knowledge_title: "Rails Guide" }
    ]
  end

  describe "#initialize" do
    it "creates builder with default settings" do
      builder = described_class.new
      expect(builder).to be_a(described_class)
    end

    it "creates builder with custom system prompt" do
      custom_prompt = "Custom prompt"
      builder = described_class.new(system_prompt: custom_prompt)
      expect(builder).to be_a(described_class)
    end

    it "creates builder with custom max tokens" do
      builder = described_class.new(max_context_tokens: 1000)
      expect(builder).to be_a(described_class)
    end
  end

  describe "#build" do
    it "returns hash with system and user prompts" do
      result = builder.build(question, chunks)
      expect(result).to include(:system, :user, :metadata)
    end

    it "includes system prompt" do
      result = builder.build(question, chunks)
      expect(result[:system]).to include("helpful assistant")
    end

    it "includes question in user prompt" do
      result = builder.build(question, chunks)
      expect(result[:user]).to include("What is Ruby?")
    end

    it "includes chunks in context" do
      result = builder.build(question, chunks)
      expect(result[:user]).to include("Ruby is a dynamic programming language")
      expect(result[:user]).to include("Ruby was created in 1995")
      expect(result[:user]).to include("Ruby on Rails is a web framework")
    end

    it "numbers chunks in context" do
      result = builder.build(question, chunks)
      expect(result[:user]).to include("[1]")
      expect(result[:user]).to include("[2]")
      expect(result[:user]).to include("[3]")
    end

    it "includes metadata" do
      result = builder.build(question, chunks)
      expect(result[:metadata][:chunks_count]).to eq(3)
      expect(result[:metadata][:estimated_tokens]).to be > 0
    end
  end

  context "with token limit" do
    let(:builder) { described_class.new(max_context_tokens: 30) }
    let(:long_chunks) do
      [
        { id: 1, content: "x" * 200, position: 1, knowledge_title: "Doc 1" },
        { id: 2, content: "y" * 200, position: 2, knowledge_title: "Doc 2" },
        { id: 3, content: "z" * 200, position: 3, knowledge_title: "Doc 3" }
      ]
    end

    it "respects token limit" do
      result = builder.build(question, long_chunks)
      # Each chunk is 200 chars = ~50 tokens, limit is 30 tokens
      # Should only include 0 chunks (or maybe 1 at most)
      expect(result[:metadata][:chunks_count]).to be <= 1
    end
  end

  context "with custom system prompt" do
    let(:custom_prompt) { "You are a Ruby expert." }
    let(:builder) { described_class.new(system_prompt: custom_prompt) }

    it "uses custom system prompt" do
      result = builder.build(question, chunks)
      expect(result[:system]).to eq(custom_prompt)
    end
  end

  context "with empty chunks" do
    it "handles empty chunks array" do
      result = builder.build(question, [])
      expect(result[:user]).to include("Context:")
      expect(result[:metadata][:chunks_count]).to eq(0)
    end
  end
end

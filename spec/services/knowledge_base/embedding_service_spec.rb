require "rails_helper"

RSpec.describe KnowledgeBase::EmbeddingService do
  let(:knowledge) do
    Knowledge.create!(
      title: "Test Document",
      content: "This is test content for embedding. It has multiple sentences to ensure proper chunking.",
      source_type: "manual"
    )
  end

  let(:client) { instance_double(AI::Client) }
  let(:service) { described_class.new(knowledge, client: client) }

  before do
    allow(client).to receive(:embed_batch).and_return([
      Array.new(1536) { rand(-1.0..1.0) }
    ])
    allow(client).to receive(:embed).and_return(Array.new(1536) { rand(-1.0..1.0) })
  end

  describe "#initialize" do
    it "creates service with knowledge record" do
      expect(service.knowledge).to eq(knowledge)
      expect(service.client).to eq(client)
    end

    it "creates chunking service with default settings" do
      expect(service.chunking_service).to be_a(Document::ChunkingService)
      expect(service.chunking_service.strategy).to eq(:recursive)
      expect(service.chunking_service.max_tokens).to eq(500)
    end

    it "allows custom client" do
      custom_client = instance_double(AI::Client)
      service = described_class.new(knowledge, client: custom_client)
      expect(service.client).to eq(custom_client)
    end
  end

  describe "#process" do
    it "returns success hash" do
      result = service.process
      expect(result[:success]).to be true
      expect(result[:chunks_count]).to be >= 1
      expect(result[:embeddings_count]).to be >= 1
      expect(result[:duration]).to be_a(Numeric)
    end

    it "creates knowledge chunks" do
      expect { service.process }.to change { knowledge.knowledge_chunks.count }.by_at_least(1)
    end

    it "generates embeddings for chunks" do
      service.process
      knowledge.knowledge_chunks.each do |chunk|
        expect(chunk.embedding).not_to be_nil
      end
    end

    it "calls client.embed_batch with chunk texts" do
      expect(client).to receive(:embed_batch).with(anything).and_return([
        Array.new(1536) { rand(-1.0..1.0) }
      ])
      service.process
    end

    it "stores embeddings as strings" do
      service.process
      knowledge.knowledge_chunks.each do |chunk|
        expect(chunk.embedding).to be_a(String)
      end
    end

    context "when knowledge has no content" do
      it "returns error for blank content" do
        knowledge.update_column(:content, "")
        result = service.process
        expect(result[:success]).to be false
        expect(result[:error]).to include("blank")
      end
    end

    context "when knowledge is not a Knowledge record" do
      it "returns error hash" do
        service = described_class.new("not a knowledge record", client: client)
        result = service.process
        expect(result[:success]).to be false
        expect(result[:error]).to include("must be a Knowledge record")
      end
    end

    context "when API call fails" do
      before do
        allow(client).to receive(:embed_batch).and_raise(AI::APIError.new("API error"))
      end

      it "returns error hash" do
        result = service.process
        expect(result[:success]).to be false
        expect(result[:error]).to include("API error")
      end
    end

    context "when rate limit is hit" do
      before do
        allow(client).to receive(:embed_batch).and_raise(AI::RateLimitError.new("Rate limit exceeded"))
        allow(client).to receive(:embed).and_return(Array.new(1536) { rand(-1.0..1.0) })
      end

      it "retries with individual embeddings" do
        expect(client).to receive(:embed).at_least(:once)
        result = service.process
        expect(result[:success]).to be true
      end
    end
  end

  describe "#process_pending" do
    before do
      # Create chunks without embeddings
      knowledge.knowledge_chunks.create!(
        content: "Test chunk without embedding",
        position: 1,
        metadata: {}
      )
    end

    it "processes only pending chunks" do
      result = service.process_pending
      expect(result[:success]).to be true
      expect(result[:chunks_count]).to be >= 1
    end

    it "generates embeddings for pending chunks" do
      service.process_pending
      knowledge.knowledge_chunks.each do |chunk|
        expect(chunk.embedding).not_to be_nil
      end
    end

    context "when no pending chunks" do
      before do
        knowledge.knowledge_chunks.update_all(embedding: Array.new(1536) { rand(-1.0..1.0) }.to_s)
      end

      it "returns message about no pending chunks" do
        result = service.process_pending
        expect(result[:success]).to be true
        expect(result[:message]).to include("No pending chunks")
      end
    end
  end

  describe "chunking behavior" do
    let(:long_content) do
      <<~TEXT
        Ruby is a dynamic programming language. It was created in 1995 by Yukihiro Matsumoto.
        
        Ruby on Rails is a popular web framework. It was created in 2004 by David Heinemeier Hansson.
        
        Ruby has a rich ecosystem of gems. These are libraries that extend functionality.
        
        Some popular gems include RSpec, Devise, and Sidekiq.
        
        Testing is important in Ruby development. RSpec is a popular testing framework.
      TEXT
    end

    before do
      knowledge.update!(content: long_content)
      # Use smaller max_tokens to force multiple chunks
      allow_any_instance_of(Document::ChunkingService).to receive(:max_tokens).and_return(50)
    end

    it "creates multiple chunks for long content" do
      service.process
      expect(knowledge.knowledge_chunks.count).to be > 1
    end

    it "assigns sequential positions to chunks" do
      service.process
      positions = knowledge.knowledge_chunks.pluck(:position).sort
      expect(positions).to eq((1..knowledge.knowledge_chunks.count).to_a)
    end
  end

  describe "error handling" do
    it "logs errors" do
      allow(client).to receive(:embed_batch).and_raise(StandardError.new("something went wrong"))

      expect(Rails.logger).to receive(:error).with(/\[KnowledgeBase::EmbeddingService\]/)
      service.process
    end

  end
end

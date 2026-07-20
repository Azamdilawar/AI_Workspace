require 'rails_helper'

RSpec.describe KnowledgeBase::SemanticSearchService do
  include FactoryBot::Syntax::Methods

  let(:client) { instance_double(AI::Client) }
  let(:service) { described_class.new(client: client) }

  describe "#initialize" do
    it "creates service with default settings" do
      service = described_class.new
      expect(service).to be_a(described_class)
    end

    it "creates service with custom client" do
      service = described_class.new(client: client)
      expect(service).to be_a(described_class)
    end

    it "creates service with custom limit" do
      service = described_class.new(client: client, limit: 10)
      expect(service).to be_a(described_class)
    end
  end

  describe "#search" do
    let!(:knowledge) do
      create(:knowledge,
        title: "Ruby Programming",
        content: "Ruby is a dynamic programming language created in 1995.",
        source_type: "manual"
      )
    end

    let!(:chunk) do
      create(:knowledge_chunk,
        knowledge: knowledge,
        content: "Ruby is a dynamic programming language created in 1995.",
        position: 1
      )
    end

    context "with valid query" do
      before do
        allow(client).to receive(:embed).with("What is Ruby?").and_return(
          Array.new(1536) { rand(-1.0..1.0) }
        )
      end

      it "returns search results" do
        # We need to set an embedding on the chunk for similarity search
        # Rails treats embedding as a string, so we cast the array
        chunk.update!(embedding: Array.new(1536) { rand(-1.0..1.0) }.to_s)

        results = service.search("What is Ruby?")
        expect(results).to be_an(Array)
      end

      it "embeds the query" do
        chunk.update!(embedding: Array.new(1536) { rand(-1.0..1.0) }.to_s)

        expect(client).to receive(:embed).with("What is Ruby?")
        service.search("What is Ruby?")
      end
    end

    context "with blank query" do
      it "raises ArgumentError" do
        expect { service.search("") }.to raise_error(ArgumentError, /Query cannot be blank/)
      end

      it "raises ArgumentError for nil" do
        expect { service.search(nil) }.to raise_error(ArgumentError, /Query cannot be blank/)
      end
    end

    context "when AI client fails" do
      before do
        allow(client).to receive(:embed).and_raise(
          AI::AuthenticationError.new("Invalid API key")
        )
      end

      it "returns error hash" do
        result = service.search("What is Ruby?")
        expect(result).to include(error: "Invalid API key")
      end
    end

    context "when rate limit is hit" do
      before do
        allow(client).to receive(:embed).and_raise(
          AI::RateLimitError.new("Rate limited")
        )
      end

      it "returns error hash" do
        result = service.search("What is Ruby?")
        expect(result).to include(error: "Rate limited")
      end
    end
  end
end

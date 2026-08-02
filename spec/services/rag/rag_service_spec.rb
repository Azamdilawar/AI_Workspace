require 'rails_helper'

RSpec.describe Rag::RagService do
  let(:client) { instance_double(AI::Client) }
  let(:service) { described_class.new(client: client) }
  let(:question) { "What is Ruby?" }
  let(:chunks) do
    [
      { id: 1, content: "Ruby is a dynamic programming language.", position: 1, knowledge_title: "Ruby Basics" },
      { id: 2, content: "Ruby was created in 1995.", position: 2, knowledge_title: "Ruby History" }
    ]
  end

  describe "#initialize" do
    it "creates service with default settings" do
      service = described_class.new
      expect(service).to be_a(described_class)
    end

    it "creates service with custom client" do
      service = described_class.new(client: client)
      expect(service).to be_a(described_class)
    end
  end

  describe "#search" do
    context "with valid question" do
      let(:search_service) { instance_double(KnowledgeBase::SemanticSearchService) }
      let(:response) { instance_double(AI::ChatResponse, content: "Ruby is a programming language.", model: "gpt-4") }

      before do
        allow(KnowledgeBase::SemanticSearchService).to receive(:new).and_return(search_service)
        allow(search_service).to receive(:search).with(question).and_return(chunks)
        allow(client).to receive(:chat).and_return(response)
      end

      it "returns answer hash" do
        result = service.search(question)
        expect(result).to include(:answer, :sources, :metadata)
      end

      it "includes answer from LLM" do
        result = service.search(question)
        expect(result[:answer]).to include("Ruby is a programming language.")
        expect(result[:raw_answer]).to eq("Ruby is a programming language.")
      end

      it "includes sources" do
        result = service.search(question)
        expect(result[:sources].length).to eq(2)
        expect(result[:sources].first[:title]).to eq("Ruby Basics")
      end

      it "includes metadata" do
        result = service.search(question)
        expect(result[:metadata][:question]).to eq(question)
        expect(result[:metadata][:chunks_used]).to eq(2)
        expect(result[:metadata][:model]).to eq("gpt-4")
      end

      it "calls search service" do
        expect(search_service).to receive(:search).with(question)
        service.search(question)
      end

      it "calls LLM with correct messages" do
        expect(client).to receive(:chat).with(array_including(
          hash_including(role: "system"),
          hash_including(role: "user")
        ))
        service.search(question)
      end
    end

    context "with blank question" do
      it "raises ArgumentError for empty string" do
        expect { service.search("") }.to raise_error(ArgumentError, /Question cannot be blank/)
      end

      it "raises ArgumentError for nil" do
        expect { service.search(nil) }.to raise_error(ArgumentError, /Question cannot be blank/)
      end
    end

    context "when search returns error" do
      let(:search_service) { instance_double(KnowledgeBase::SemanticSearchService) }

      before do
        allow(KnowledgeBase::SemanticSearchService).to receive(:new).and_return(search_service)
        allow(search_service).to receive(:search).and_return({ error: "API Error" })
      end

      it "returns error hash" do
        result = service.search(question)
        expect(result).to include(error: "No relevant information found in the knowledge base")
      end
    end

    context "when search returns empty results" do
      let(:search_service) { instance_double(KnowledgeBase::SemanticSearchService) }

      before do
        allow(KnowledgeBase::SemanticSearchService).to receive(:new).and_return(search_service)
        allow(search_service).to receive(:search).and_return([])
      end

      it "returns error hash" do
        result = service.search(question)
        expect(result).to include(error: "No relevant information found in the knowledge base")
      end
    end

    context "when LLM fails" do
      let(:search_service) { instance_double(KnowledgeBase::SemanticSearchService) }

      before do
        allow(KnowledgeBase::SemanticSearchService).to receive(:new).and_return(search_service)
        allow(search_service).to receive(:search).and_return(chunks)
        allow(client).to receive(:chat).and_raise(AI::AuthenticationError.new("Invalid API key"))
      end

      it "returns error hash" do
        result = service.search(question)
        expect(result).to include(error: "Invalid API key")
      end
    end
  end
end

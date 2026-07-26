require 'rails_helper'

RSpec.describe "Rag", type: :request do
  describe "GET /rag" do
    it "renders the RAG page" do
      get rag_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ask Questions")
    end

    it "renders question form" do
      get rag_path
      expect(response.body).to include("Ask")
    end

    it "handles question parameter" do
      get rag_path, params: { question: "test" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("test")
    end
  end
end

require 'rails_helper'

RSpec.describe "Knowledge", type: :request do
  include FactoryBot::Syntax::Methods

  describe "GET /knowledge" do
    it "renders the index page" do
      get knowledge_index_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Documents")
    end
  end

  describe "GET /knowledge/new" do
    it "renders the new page" do
      get new_knowledge_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Upload Document")
    end
  end

  describe "POST /knowledge" do
    it "creates a new knowledge document" do
      expect {
        post knowledge_index_path, params: {
          knowledge: {
            title: "Test Document",
            content: "This is test content for the knowledge base.",
            source_type: "manual"
          }
        }
      }.to change(Knowledge, :count).by(1)

      expect(response).to redirect_to(knowledge_path(Knowledge.last))
    end

    it "creates chunks for the document" do
      post knowledge_index_path, params: {
        knowledge: {
          title: "Test Document",
          content: "This is test content for the knowledge base.",
          source_type: "manual"
        }
      }

      knowledge = Knowledge.last
      expect(knowledge.knowledge_chunks.count).to be > 0
    end

    it "accepts a file upload and reads its content" do
      file = Rack::Test::UploadedFile.new(
        StringIO.new("Employee handbook content for testing."),
        "text/plain",
        original_filename: "handbook.txt"
      )

      expect {
        post knowledge_index_path, params: {
          knowledge: { title: "", file: file, content: "" }
        }
      }.to change(Knowledge, :count).by(1)

      knowledge = Knowledge.last
      expect(knowledge.title).to eq("handbook.txt")
      expect(knowledge.content).to eq("Employee handbook content for testing.")
      expect(knowledge.source_type).to eq("upload")
    end
  end

  describe "DELETE /knowledge/:id" do
    it "deletes the document" do
      knowledge = create(:knowledge)

      expect {
        delete knowledge_path(knowledge)
      }.to change(Knowledge, :count).by(-1)

      expect(response).to redirect_to(knowledge_index_path)
    end
  end
end

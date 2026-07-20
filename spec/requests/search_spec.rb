require 'rails_helper'

RSpec.describe "Search", type: :request do
  describe "GET /search" do
    it "renders the search page" do
      get search_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Semantic Search")
    end

    it "renders search form" do
      get search_path
      expect(response.body).to include("Search")
    end

    it "handles query parameter" do
      get search_path, params: { query: "test" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("test")
    end
  end
end

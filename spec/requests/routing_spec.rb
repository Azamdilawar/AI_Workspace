require "rails_helper"

RSpec.describe "Routing and Placeholders", type: :request do
  describe "GET /" do
    it "renders the dashboard successfully" do
      get root_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Dashboard")
      expect(response.body).to include("Welcome to AI Workspace")
    end
  end

  describe "GET /conversations" do
    it "renders the conversations index" do
      get conversations_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("AI Chat")
    end
  end

  describe "GET /email_generator" do
    it "renders the Email Generator page successfully" do
      get email_generator_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Email Generator")
      expect(response.body).to include("Generate Email")
    end
  end

  describe "GET /summarizer" do
    it "renders the Summarizer page successfully" do
      get summarizer_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Summarizer")
      expect(response.body).to include("Scheduled for Phase 1")
    end
  end

  describe "GET /settings" do
    it "renders the Settings page successfully" do
      get settings_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Settings")
      expect(response.body).to include("API & Model Configurations")
    end
  end
end

require 'rails_helper'

RSpec.describe "Admin::SeoMetadata", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/admin/seo_metadata/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get "/admin/seo_metadata/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /edit" do
    it "returns http success" do
      get "/admin/seo_metadata/edit"
      expect(response).to have_http_status(:success)
    end
  end

end

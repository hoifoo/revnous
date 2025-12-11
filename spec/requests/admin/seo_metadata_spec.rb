require 'rails_helper'

RSpec.describe "Admin::SeoMetadata", type: :request do
  let(:admin) { create(:user, :admin) }

  before do
    sign_in admin
  end

  describe "GET /index" do
    it "returns http success" do
      get admin_seo_metadata_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get new_admin_seo_metadatum_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /edit" do
    let!(:seo_metadatum) { SeoMetadatum.create!(page_identifier: "home#index", page_title: "Test") }

    it "returns http success" do
      get edit_admin_seo_metadatum_path(seo_metadatum)
      expect(response).to have_http_status(:success)
    end
  end
end

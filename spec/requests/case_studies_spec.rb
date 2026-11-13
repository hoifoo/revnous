require "rails_helper"

RSpec.describe "Case studies", type: :request do
  DEMO_QUOTES = [
    "We needed something seamless but powerful",
    "A/B testing tools have been game-changing",
    "post-purchase content",
    "roadmap never stalls",
    "Improved customer retention and brand loyalty"
  ].freeze

  describe "GET /case_studies/:id" do
    it "renders stat labels, key results and the review quote from the record" do
      case_study = create(:case_study,
        conversion_rate: "3 hours", primary_stat_label: "To undo an ended campaign",
        revenue_increase: "Live chat", secondary_stat_label: "With the team that builds the app",
        product_features: "Campaign Controls",
        key_results: "Pause and resume a live campaign\n\nUndo an ended campaign\n",
        quote: "Customer service was super fast.",
        quote_attribution: "Tiny Tales, India · Shopify App Store review")

      get case_study_path(case_study)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("To undo an ended campaign", "With the team that builds the app", "Feature used")
      expect(response.body).to include("Pause and resume a live campaign", "Undo an ended campaign")
      expect(response.body).to include("Customer service was super fast.", "Tiny Tales, India · Shopify App Store review")
      DEMO_QUOTES.each { |quote| expect(response.body).not_to include(quote) }
    end

    it "renders without stats, key results, quote or product features" do
      case_study = create(:case_study, product_features: nil)

      get case_study_path(case_study)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("<blockquote")
    end

    it "redirects an unknown id to the case study list" do
      get case_study_path(id: 999_999)

      expect(response).to redirect_to(case_studies_path)
      expect(response).to have_http_status(:moved_permanently)
    end
  end

  describe "db/data/case_studies.yml" do
    let(:entries) { YAML.safe_load_file(Rails.root.join("db/data/case_studies.yml")) }

    it "only uses case_studies columns and builds valid records" do
      columns = CaseStudy.column_names
      entries.each do |attrs|
        expect(attrs.keys - columns).to be_empty
        expect(CaseStudy.new(attrs)).to be_valid
      end
    end

    it "attributes every quote to a Shopify App Store review" do
      entries.select { |attrs| attrs["quote"].present? }.each do |attrs|
        expect(attrs["quote_attribution"]).to end_with("Shopify App Store review")
      end
    end
  end
end

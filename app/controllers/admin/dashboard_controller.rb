class Admin::DashboardController < Admin::BaseController
  def index
    @case_studies_count = CaseStudy.count
    @blogs_count = Blog.count
    @published_blogs_count = Blog.published.count
    @featured_blogs_count = Blog.featured.count
    @active_case_studies_count = CaseStudy.where(ad_active: true).count
    @notices_count = Notice.count
    @active_notice = Notice.active_notice
    @products_count = Product.count
    @active_products_count = Product.active.count
    @pricing_plans_count = PricingPlan.count
    @trusted_brands_count = TrustedBrand.count
    @partners_count = Partner.count
    @active_partners_count = Partner.active.count
    @newsletter_subscribers_count = NewsletterSubscriber.active.count
    @legal_documents_count = LegalDocument.count
    @active_legal_documents_count = LegalDocument.active.count
    @beta_users_count = BetaUser.count
    @beta_users_this_week = BetaUser.where("created_at >= ?", 1.week.ago).count
  end
end

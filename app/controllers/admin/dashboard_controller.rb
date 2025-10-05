class Admin::DashboardController < Admin::BaseController
  def index
    @case_studies_count = CaseStudy.count
    @blogs_count = Blog.count
    @published_blogs_count = Blog.published.count
    @featured_blogs_count = Blog.featured.count
    @active_case_studies_count = CaseStudy.where(ad_active: true).count
    @notices_count = Notice.count
    @active_notice = Notice.active_notice
    @pricing_plans_count = PricingPlan.count
    @trusted_brands_count = TrustedBrand.count
  end
end

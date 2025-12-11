class HomeController < ApplicationController
  def index
    @page_title = "Revnous - Revenue Optimization for Shopify"
    @page_description = "Revnous helps Shopify merchants optimize revenue with powerful pricing tools, analytics, and automation. Maximize your profits with data-driven insights."
    @featured_case_studies = CaseStudy.where(ad_active: true).limit(6)
    @special_offer = SpecialOffer.for_page("home").first
    @partners = Partner.active.ordered
    @trusted_brands = TrustedBrand.ordered
    @featured_blogs = Blog.published.featured_on_home.limit(3)
    @featured_products = Product.active.featured_on_home.with_cover_photo.ordered.limit(3)
  end
end

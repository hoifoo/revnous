class PricingController < ApplicationController
  def index
    @products = Product.active.ordered.includes(:pricing_plans)
    @pricing_plans = PricingPlan.where(product_id: nil).ordered
    @trusted_brands = TrustedBrand.ordered
    @special_offer = SpecialOffer.for_page('pricing').first
  end
end

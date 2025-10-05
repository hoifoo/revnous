class PricingController < ApplicationController
  def index
    @pricing_plans = PricingPlan.ordered
    @trusted_brands = TrustedBrand.ordered
    @special_offer = SpecialOffer.for_page('pricing').first
  end
end

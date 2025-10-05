class PricingController < ApplicationController
  def index
    @pricing_plans = PricingPlan.ordered
    @trusted_brands = TrustedBrand.ordered
  end
end

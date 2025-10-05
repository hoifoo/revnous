class PricingController < ApplicationController
  def index
    @pricing_plans = PricingPlan.ordered
  end
end

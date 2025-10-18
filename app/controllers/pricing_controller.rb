class PricingController < ApplicationController
  def product_pricing
    product_slug = params[:product_slug].parameterize
    @product = Product.active.ordered.find { |p| p.name.parameterize == product_slug }

    if @product.nil?
      redirect_to products_path, alert: "Product not found"
      return
    end

    @pricing_plans = @product.pricing_plans.ordered
    @trusted_brands = TrustedBrand.ordered
    @special_offer = SpecialOffer.for_page('pricing').first

    render :show
  end
end

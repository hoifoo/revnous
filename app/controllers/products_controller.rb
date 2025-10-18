class ProductsController < ApplicationController
  def index
    @products = Product.active.ordered
  end

  def show
    @product = Product.active.find(params[:id])
    @pricing_plans = @product.pricing_plans.ordered
    @trusted_brands = TrustedBrand.ordered
  end
end

class ProductsController < ApplicationController
  def index
    @page_title = "Products - Revnous"
    @page_description = "Explore our suite of revenue optimization tools designed specifically for Shopify merchants."
    @products = Product.active.ordered
  end

  def show
    @product = Product.active.find(params[:id])
    @page_title = @product.seo_title
    @page_description = @product.seo_description
    @page_og_type = "product"
    @page_og_image = @product.cover_photo_url if @product.cover_photo.attached?
    @canonical_url = product_url(@product)
    @pricing_plans = @product.pricing_plans.ordered
    @trusted_brands = TrustedBrand.ordered
  end
end

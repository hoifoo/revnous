module PricingHelper
  def pricing_url_for(product)
    if product
      product_slug = product.is_a?(Product) ? product.name.parameterize : product.to_s.parameterize
      product_pricing_path(product_slug: product_slug)
    else
      # If no product is provided, redirect to products page
      products_path
    end
  end
end

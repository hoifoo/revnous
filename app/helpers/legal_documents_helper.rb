module LegalDocumentsHelper
  def privacy_policy_url_for(product = nil)
    if product
      product_slug = product.is_a?(Product) ? product.name.parameterize : product.to_s.parameterize
      product_privacy_policy_path(product_slug: product_slug)
    else
      privacy_policy_path
    end
  end

  def terms_of_service_url_for(product = nil)
    if product
      product_slug = product.is_a?(Product) ? product.name.parameterize : product.to_s.parameterize
      product_terms_of_service_path(product_slug: product_slug)
    else
      terms_of_service_path
    end
  end
end

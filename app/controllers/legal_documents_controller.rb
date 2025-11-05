class LegalDocumentsController < ApplicationController
  before_action :set_product, only: [ :product_privacy_policy, :product_terms_of_service ]

  # Global legal documents
  def privacy_policy
    @legal_document = LegalDocument.current_privacy_policy
    @product = nil

    if @legal_document
      render :show
    else
      redirect_to root_path, alert: "Privacy Policy not available"
    end
  end

  def terms_of_service
    @legal_document = LegalDocument.current_terms_of_service
    @product = nil

    if @legal_document
      render :show
    else
      redirect_to root_path, alert: "Terms of Service not available"
    end
  end

  # Product-scoped legal documents
  def product_privacy_policy
    @legal_document = LegalDocument.current_privacy_policy(@product)

    if @legal_document
      render :show
    else
      redirect_to root_path, alert: "Privacy Policy not available for this product"
    end
  end

  def product_terms_of_service
    @legal_document = LegalDocument.current_terms_of_service(@product)

    if @legal_document
      render :show
    else
      redirect_to root_path, alert: "Terms of Service not available for this product"
    end
  end

  private

  def set_product
    @product = Product.find_by!(url: params[:product_slug]) || Product.find_by!(id: params[:product_slug])
  rescue ActiveRecord::RecordNotFound
    # Try to find by name slug
    product_slug = params[:product_slug].parameterize
    @product = Product.all.find { |p| p.name.parameterize == product_slug }

    unless @product
      redirect_to root_path, alert: "Product not found"
    end
  end
end

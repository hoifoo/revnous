# frozen_string_literal: true

class SitemapController < ApplicationController
  def index
    @blogs = Blog.published.order(updated_at: :desc)
    @case_studies = CaseStudy.all.order(updated_at: :desc)
    @products = Product.all.order(updated_at: :desc)

    respond_to do |format|
      format.xml
    end
  end
end

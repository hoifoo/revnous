class CaseStudiesController < ApplicationController
  def index
    @case_studies = CaseStudy.all

    # Filter by industry
    @case_studies = @case_studies.where(industry: params[:industry]) if params[:industry].present?

    # Filter by product features
    @case_studies = @case_studies.where("product_features LIKE ?", "%#{params[:product_features]}%") if params[:product_features].present?

    # Filter by ad active status
    @case_studies = @case_studies.where(ad_active: params[:ad_active]) if params[:ad_active].present?

    # Search by name or description
    if params[:search].present?
      @case_studies = @case_studies.where("name LIKE ? OR description LIKE ?", "%#{params[:search]}%", "%#{params[:search]}%")
    end

    # Pagination (9 per page like in the image)
    @case_studies = @case_studies.page(params[:page]).per(9)

    # Get unique values for filters
    @industries = CaseStudy.distinct.pluck(:industry).compact
    @product_features_list = CaseStudy.distinct.pluck(:product_features).compact

    @special_offer = SpecialOffer.for_page("case_studies").first
  end

  def show
    @case_study = CaseStudy.find(params[:id])
    @related_case_studies = CaseStudy.where.not(id: @case_study.id)
                                      .where(industry: @case_study.industry)
                                      .limit(3)

    # If not enough related in same industry, get random ones
    if @related_case_studies.count < 3
      @related_case_studies = CaseStudy.where.not(id: @case_study.id).limit(3)
    end
  end
end

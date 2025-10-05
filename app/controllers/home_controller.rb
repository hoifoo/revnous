class HomeController < ApplicationController
  def index
    @featured_case_studies = CaseStudy.where(ad_active: true).limit(6)
  end
end

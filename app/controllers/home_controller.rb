class HomeController < ApplicationController
  def index
    @featured_case_studies = CaseStudy.where(ad_active: true).limit(6)
    @special_offer = SpecialOffer.for_page('home').first
  end
end

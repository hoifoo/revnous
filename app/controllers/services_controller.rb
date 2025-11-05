class ServicesController < ApplicationController
  def index
    @special_offer = SpecialOffer.for_page("services").first
  end
end

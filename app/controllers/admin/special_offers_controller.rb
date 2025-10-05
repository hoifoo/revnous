class Admin::SpecialOffersController < Admin::BaseController
  before_action :set_special_offer, only: [:edit, :update, :destroy]

  def index
    @special_offers = SpecialOffer.order(created_at: :desc).page(params[:page]).per(20)
  end

  def new
    @special_offer = SpecialOffer.new
  end

  def create
    @special_offer = SpecialOffer.new(special_offer_params)
    @special_offer.placement_tags_list = placement_tags_params if placement_tags_params.any?

    if @special_offer.save
      redirect_to admin_special_offers_path, notice: "Special offer created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @special_offer.placement_tags_list = placement_tags_params if placement_tags_params.any?

    if @special_offer.update(special_offer_params)
      redirect_to admin_special_offers_path, notice: "Special offer updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @special_offer.destroy
    redirect_to admin_special_offers_path, notice: "Special offer deleted successfully."
  end

  private

  def set_special_offer
    @special_offer = SpecialOffer.find(params[:id])
  end

  def special_offer_params
    params.require(:special_offer).permit(
      :title, :subtitle, :description, :terms_text,
      :cta_text, :cta_url, :logo_text, :active
    )
  end

  def placement_tags_params
    params[:special_offer][:placement_tags]&.reject(&:blank?) || []
  end
end

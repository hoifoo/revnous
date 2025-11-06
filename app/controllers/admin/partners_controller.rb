class Admin::PartnersController < Admin::BaseController
  before_action :set_partner, only: [ :edit, :update, :destroy ]

  def index
    @partners = Partner.ordered.page(params[:page]).per(20)
  end

  def new
    @partner = Partner.new
  end

  def create
    @partner = Partner.new(partner_params)

    if @partner.save
      redirect_to admin_partners_path, notice: "Partner created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @partner.update(partner_params)
      redirect_to admin_partners_path, notice: "Partner updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @partner.destroy
    redirect_to admin_partners_path, notice: "Partner deleted successfully."
  end

  private

  def set_partner
    @partner = Partner.find(params[:id])
  end

  def partner_params
    params.require(:partner).permit(:name, :website_url, :description, :active, :position, :logo, product_ids: [])
  end
end

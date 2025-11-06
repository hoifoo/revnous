class Admin::TrustedBrandsController < Admin::BaseController
  before_action :set_trusted_brand, only: [ :edit, :update, :destroy ]

  def index
    @trusted_brands = TrustedBrand.ordered.page(params[:page]).per(20)
  end

  def new
    @trusted_brand = TrustedBrand.new
  end

  def create
    @trusted_brand = TrustedBrand.new(trusted_brand_params)

    if @trusted_brand.save
      redirect_to admin_trusted_brands_path, notice: "Trusted brand created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @trusted_brand.update(trusted_brand_params)
      redirect_to admin_trusted_brands_path, notice: "Trusted brand updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @trusted_brand.destroy
    redirect_to admin_trusted_brands_path, notice: "Trusted brand deleted successfully."
  end

  private

  def set_trusted_brand
    @trusted_brand = TrustedBrand.find(params[:id])
  end

  def trusted_brand_params
    params.require(:trusted_brand).permit(:name, :font_style, :position)
  end
end

class Admin::PricingPlansController < Admin::BaseController
  before_action :set_pricing_plan, only: [:edit, :update, :destroy]

  def index
    @pricing_plans = PricingPlan.ordered.page(params[:page]).per(20)
  end

  def new
    @pricing_plan = PricingPlan.new
  end

  def create
    @pricing_plan = PricingPlan.new(pricing_plan_params)
    @pricing_plan.features_list = feature_params if feature_params.any?

    if @pricing_plan.save
      redirect_to admin_pricing_plans_path, notice: "Pricing plan created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @pricing_plan.features_list = feature_params if feature_params.any?

    if @pricing_plan.update(pricing_plan_params)
      redirect_to admin_pricing_plans_path, notice: "Pricing plan updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @pricing_plan.destroy
    redirect_to admin_pricing_plans_path, notice: "Pricing plan deleted successfully."
  end

  private

  def set_pricing_plan
    @pricing_plan = PricingPlan.find(params[:id])
  end

  def pricing_plan_params
    params.require(:pricing_plan).permit(
      :name, :price, :billing_period, :description, :order_limit,
      :cta_text, :cta_url, :trial_text, :is_popular, :shopify_plus_only, :position
    )
  end

  def feature_params
    params[:pricing_plan][:features]&.reject(&:blank?) || []
  end
end

class Admin::CaseStudiesController < Admin::BaseController
  before_action :set_case_study, only: [:edit, :update, :destroy]

  def index
    @case_studies = CaseStudy.order(created_at: :desc).page(params[:page]).per(20)
  end

  def new
    @case_study = CaseStudy.new
  end

  def create
    @case_study = CaseStudy.new(case_study_params)

    if @case_study.save
      redirect_to admin_case_studies_path, notice: "Case study created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @case_study.update(case_study_params)
      redirect_to admin_case_studies_path, notice: "Case study updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @case_study.destroy
    redirect_to admin_case_studies_path, notice: "Case study deleted successfully."
  end

  private

  def set_case_study
    @case_study = CaseStudy.find(params[:id])
  end

  def case_study_params
    params.require(:case_study).permit(
      :name, :industry, :product_features, :ad_active,
      :description, :conversion_rate, :revenue_increase,
      :challenge, :solution, :results, :image_url, :image
    )
  end
end

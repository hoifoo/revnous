class Admin::NoticesController < Admin::BaseController
  before_action :set_notice, only: [ :edit, :update, :destroy ]

  def index
    @notices = Notice.order(created_at: :desc).page(params[:page]).per(20)
  end

  def new
    @notice = Notice.new
  end

  def create
    @notice = Notice.new(notice_params)

    if @notice.save
      redirect_to admin_notices_path, notice: "Notice created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @notice.update(notice_params)
      redirect_to admin_notices_path, notice: "Notice updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @notice.destroy
    redirect_to admin_notices_path, notice: "Notice deleted successfully."
  end

  private

  def set_notice
    @notice = Notice.find(params[:id])
  end

  def notice_params
    params.require(:notice).permit(:message, :link_url, :link_text, :background_color, :active)
  end
end

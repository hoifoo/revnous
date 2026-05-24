class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [ :edit, :update, :destroy ]

  def index
    @users = User.order(:first_name, :last_name).page(params[:page]).per(20)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to admin_users_path, notice: "User was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    params_to_update = if params[:user][:password].blank?
      user_params.except(:password, :password_confirmation)
    else
      user_params
    end

    if @user.update(params_to_update)
      redirect_to admin_users_path, notice: "User profile was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy
    redirect_to admin_users_path, notice: "User was successfully deleted."
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(
      :first_name, :last_name, :email, :password, :password_confirmation,
      :bio, :job_title, :linkedin_url, :twitter_handle, :avatar, :admin
    )
  end
end

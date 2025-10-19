class Admin::BetaUsersController < Admin::BaseController
  def index
    @beta_users = BetaUser.includes(:product).recent.page(params[:page]).per(20)

    # Filter by product if specified
    if params[:product_id].present?
      @beta_users = @beta_users.where(product_id: params[:product_id])
    end

    # Search functionality
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @beta_users = @beta_users.where(
        "name LIKE ? OR email LIKE ? OR company LIKE ?",
        search_term, search_term, search_term
      )
    end
  end

  def destroy
    @beta_user = BetaUser.find(params[:id])
    @beta_user.destroy
    redirect_to admin_beta_users_path, notice: "Beta user deleted successfully."
  end
end

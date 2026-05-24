# frozen_string_literal: true

class InvitationsController < ApplicationController
  before_action :load_invitation
  before_action :ensure_acceptable, only: [ :accept, :setup, :complete ]

  def show
  end

  def accept
    redirect_to setup_invitation_path(@invitation.token), notice: "Invitation accepted! Please set up your account below."
  end

  def reject
    if @invitation.status == "pending"
      @invitation.reject!
      redirect_to root_path, notice: "Invitation declined."
    else
      redirect_to invitation_path(@invitation.token)
    end
  end

  def setup
  end

  def complete
    user = User.new(complete_params)
    user.email = @invitation.email
    user.admin = true

    if user.save
      @invitation.accept!
      sign_in(user)
      redirect_to admin_root_path, notice: "Welcome! Your admin account has been created."
    else
      @user = user
      render :setup, status: :unprocessable_entity
    end
  end

  private

  def load_invitation
    @invitation = AdminInvitation.find_by(token: params[:token])
    unless @invitation
      render plain: "Invitation not found.", status: :not_found
    end
  end

  def ensure_acceptable
    unless @invitation.acceptable?
      render :expired, status: :gone
    end
  end

  def complete_params
    params.require(:user).permit(:first_name, :last_name, :password, :password_confirmation)
  end
end

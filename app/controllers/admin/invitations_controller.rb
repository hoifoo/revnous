# frozen_string_literal: true

class Admin::InvitationsController < Admin::BaseController
  def index
    @invitations = AdminInvitation.includes(:invited_by).order(created_at: :desc)
  end

  def new
    @invitation = AdminInvitation.new
  end

  def create
    @invitation = AdminInvitation.new(invitation_params)
    @invitation.invited_by = current_user

    if @invitation.save
      InvitationMailer.invite(@invitation).deliver_later
      redirect_to admin_invitations_path, notice: "Invitation sent to #{@invitation.email}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def invitation_params
    params.require(:admin_invitation).permit(:email)
  end
end

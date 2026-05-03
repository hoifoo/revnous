# frozen_string_literal: true

class InvitationMailer < ApplicationMailer
  def invite(invitation)
    @invitation = invitation
    @inviter_name = invitation.invited_by.first_name.presence || invitation.invited_by.email
    @accept_url = invitation_url(invitation.token, host: default_url_options[:host], protocol: default_url_options[:protocol] || "https")
    @expires_at = invitation.expires_at

    mail(
      to: invitation.email,
      subject: "You've been invited to join Revnous as an admin"
    )
  end
end

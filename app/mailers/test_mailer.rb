# frozen_string_literal: true

class TestMailer < ApplicationMailer
  def ping(to:)
    mail(
      to: to,
      subject: "ZeptoMail test — #{Time.current.strftime("%Y-%m-%d %H:%M:%S %Z")}"
    )
  end
end

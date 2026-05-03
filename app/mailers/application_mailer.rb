class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "noreply@revnous.com")
  layout "mailer"
end

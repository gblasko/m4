class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "marina@example.com")
  layout "mailer"
end

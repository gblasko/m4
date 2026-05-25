# Mail delivery method that routes ActionMailer through Resend's HTTP API
# (instead of SMTP). Registered as `:resend` in
# config/initializers/resend_delivery.rb and selected per-env via
# `config.action_mailer.delivery_method = :resend`.
#
# This is what makes `AnyMailer#some_action.deliver_later` actually send in
# production — without it, Rails falls back to `:smtp` with no
# `smtp_settings`, and every mail silently fails (raise_delivery_errors
# defaults to false in production).
class ResendDelivery
  attr_accessor :settings

  def initialize(settings = {})
    self.settings = settings
  end

  def deliver!(mail)
    ResendAdapter.send_email(mail)
  end
end

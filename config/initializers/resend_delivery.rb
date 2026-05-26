ActiveSupport.on_load(:action_mailer) do
  ActionMailer::Base.add_delivery_method :resend, ResendDelivery
end

# Warn loudly at boot if Resend isn't fully configured for the env that uses
# it. Catches the easy footgun of forgetting to set MAIL_FROM in Render.
Rails.application.config.after_initialize do
  next unless ActionMailer::Base.delivery_method == :resend
  if ENV["RESEND_API_KEY"].blank?
    Rails.logger.warn "[ResendAdapter] RESEND_API_KEY is not set — emails will be logged, not sent."
  end
  if ENV["MAIL_FROM"].blank?
    Rails.logger.warn "[ResendAdapter] MAIL_FROM is not set — falling back to onboarding@resend.dev. Set MAIL_FROM in Render to your verified sender."
  end
end

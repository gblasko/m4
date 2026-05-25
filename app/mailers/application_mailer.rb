class ApplicationMailer < ActionMailer::Base
  # ENV.fetch only falls back when the var is *unset*. If MAIL_FROM is set to
  # an empty string in Render's dashboard, fetch returns "" and Resend rejects
  # the resulting null `from` header with a 422. Use `presence` so blanks
  # also fall through to the default.
  #
  # The fallback `onboarding@resend.dev` is Resend's universal sender — every
  # account can send from it without verifying a domain. Replace with your
  # own verified sender (e.g. "Marina Ops <noreply@yourdomain.com>") via
  # MAIL_FROM once your domain is set up in resend.com → Domains.
  default from: ENV["MAIL_FROM"].presence || "onboarding@resend.dev"
  layout "mailer"
end

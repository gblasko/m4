class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  # Resend webhook: {"type":"email.delivered", "data":{"email_id": "...", "to":[...]}}
  def resend
    return head :unauthorized unless valid_resend_secret?
    payload = parse_payload
    return head :ok if payload.blank?
    type = payload["type"].to_s
    email_id = payload.dig("data", "email_id")
    notification = Notification.find_by(provider_id: email_id) if email_id.present?
    if notification
      case type
      when "email.delivered" then notification.update(status: "delivered", delivered_at: Time.current)
      when "email.bounced", "email.complained"
        notification.update(status: "bounced", failed_at: Time.current, error: type)
      end
    end
    head :ok
  end

  # Twilio webhook (form-encoded): MessageStatus=delivered/failed, MessageSid=..., From=...
  def twilio
    sid = params[:MessageSid].presence
    status = params[:MessageStatus].to_s
    body = params[:Body].to_s.strip.upcase
    notif = Notification.find_by(provider_id: sid) if sid

    if notif
      case status
      when "delivered" then notif.update(status: "delivered", delivered_at: Time.current)
      when "failed", "undelivered" then notif.update(status: "failed", failed_at: Time.current, error: status)
      end
    end

    # STOP handling: opt-out user from SMS
    if %w[STOP STOPALL UNSUBSCRIBE QUIT CANCEL END].include?(body)
      digits = params[:From].to_s.gsub(/\D/, "")
      user = User.where("regexp_replace(coalesce(phone,''), '\\D', '', 'g') = ?", digits).first
      if user
        prefs = (user.notification_prefs.presence || User::DEFAULT_PREFS).deep_dup
        prefs.each { |_event, ch| ch["sms"] = false if ch.is_a?(Hash) && ch.key?("sms") }
        user.update(notification_prefs: prefs)
      end
    end
    head :ok
  end

  private

  def valid_resend_secret?
    expected = ENV["RESEND_WEBHOOK_SECRET"]
    return true if expected.blank?  # not enforced in dev
    provided = request.headers["X-Webhook-Secret"]
    ActiveSupport::SecurityUtils.secure_compare(expected, provided.to_s)
  end

  def parse_payload
    JSON.parse(request.body.read) rescue {}
  end
end

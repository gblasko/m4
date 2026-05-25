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

  # Quo (OpenPhone) webhook. JSON body roughly shaped like:
  #   { "type": "message.delivered" | "message.received" | ...,
  #     "data": { "id": "AC...", "status": "delivered"|"undelivered"|...,
  #               "direction": "outgoing"|"incoming",
  #               "from": "+1555...", "to": ["+1555..."], "text": "..." } }
  # Use the dashboard at quo.com to subscribe this URL to message events.
  def quo
    payload = parse_payload
    return head :ok if payload.blank?

    data = payload["data"].is_a?(Hash) ? payload["data"] : {}
    message_id = data["id"].presence
    status     = data["status"].to_s
    direction  = data["direction"].to_s
    notif = Notification.find_by(provider_id: message_id) if message_id

    if notif && direction != "incoming"
      case status
      when "delivered"
        notif.update(status: "delivered", delivered_at: Time.current)
      when "undelivered", "failed"
        notif.update(status: "failed", failed_at: Time.current, error: status)
      end
    end

    # CTIA-mandated STOP/UNSUBSCRIBE handling on inbound messages
    if direction == "incoming"
      text = data["text"].to_s.strip.upcase
      if %w[STOP STOPALL UNSUBSCRIBE QUIT CANCEL END].include?(text)
        from = data["from"].to_s
        digits = from.gsub(/\D/, "")
        user = User.where("regexp_replace(coalesce(phone,''), '\\D', '', 'g') = ?", digits).first
        if user
          prefs = (user.notification_prefs.presence || User::DEFAULT_PREFS).deep_dup
          prefs.each { |_event, ch| ch["sms"] = false if ch.is_a?(Hash) && ch.key?("sms") }
          user.update(notification_prefs: prefs)
        end
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

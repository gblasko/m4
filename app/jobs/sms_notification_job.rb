class SmsNotificationJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(notification_id)
    notif = Notification.find_by(id: notification_id)
    return if notif.nil? || notif.status != "pending"

    notif.update!(attempts: notif.attempts + 1)
    body = SmsBodyBuilder.for(notif)
    message_id = QuoAdapter.send_sms(to: notif.to_address, body: body)
    notif.update!(status: "sent", sent_at: Time.current, provider_id: message_id)
  rescue => e
    notif&.update(error: e.message[0, 500])
    if notif&.attempts.to_i >= 5
      notif.update(status: "failed", failed_at: Time.current)
    else
      raise
    end
  end
end

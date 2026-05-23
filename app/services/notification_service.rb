class NotificationService
  EVENT_DEFAULT_CHANNELS = {
    "request_submitted"  => %w[email],
    "request_started"    => %w[email],
    "request_completed"  => %w[email sms],
    "request_cancelled"  => %w[email sms],
    "public_note_added"  => %w[email],
    "request_assigned"   => %w[email]
  }.freeze

  def self.dispatch(event:, request: nil, recipient:)
    channels = EVENT_DEFAULT_CHANNELS.fetch(event, [])
    channels.each do |channel|
      next unless can_send?(channel: channel, user: recipient)
      next unless recipient.prefers?(event, channel)
      record_and_enqueue(event: event, channel: channel, user: recipient, request: request)
    end
  end

  def self.dispatch_for_status_change(req)
    event =
      case req.status
      when "in_progress" then "request_started"
      when "completed"   then "request_completed"
      when "cancelled"   then "request_cancelled"
      end
    return unless event
    dispatch(event: event, request: req, recipient: req.customer)
  end

  def self.record_and_enqueue(event:, channel:, user:, request:)
    to_address = (channel == "email" ? user.email : user.phone)
    return if to_address.blank?

    notif = Notification.create!(
      user: user,
      request: request,
      event: event,
      channel: channel,
      to_address: to_address,
      status: "pending"
    )

    case channel
    when "email" then EmailNotificationJob.perform_later(notif.id)
    when "sms"   then SmsNotificationJob.perform_later(notif.id)
    end
  end

  def self.can_send?(channel:, user:)
    case channel
    when "email" then user.email.present?
    when "sms"   then user.phone.present? && sms_window_open?(user)
    else false
    end
  end

  def self.sms_window_open?(user)
    tz = user.organization.locations.first&.timezone || "America/Chicago"
    hour = Time.current.in_time_zone(tz).hour
    (8..20).cover?(hour)
  end
end

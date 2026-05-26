class PushoverNotificationJob < ApplicationJob
  queue_as :default
  retry_on PushoverAdapter::Error, wait: :polynomially_longer, attempts: 5

  def perform(event:, request_id:)
    req = Request.find_by(id: request_id)
    return if req.nil?

    group_key = req.location&.pushover_group_key
    return if group_key.blank?

    PushoverAdapter.send_message(
      group_key: group_key,
      message:   build_message(event, req),
      title:     build_title(event, req),
      url:       request_url(req)
    )
  end

  private

  def build_title(event, req)
    label = case event
            when "request_submitted" then "New request"
            when "request_started"   then "Started"
            when "request_completed" then "Completed"
            when "request_cancelled" then "Cancelled"
            when "request_assigned"  then "Assigned"
            when "public_note_added" then "Note added"
            else event.to_s.humanize
            end
    "#{label} — #{req.location.name}"
  end

  def build_message(_event, req)
    "#{req.request_type.name} for #{req.customer.name} " \
      "— #{req.in_tz.strftime('%a %b %-d, %-l:%M %p')}"
  end

  def request_url(req)
    Rails.application.routes.url_helpers.request_url(req, host: ENV.fetch("APP_HOST", "localhost:3000"))
  rescue ActionController::UrlGenerationError
    nil
  end
end

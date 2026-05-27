class SmsBodyBuilder
  def self.for(notif)
    req = notif.request
    boat = req&.boat&.name
    type = req&.request_type&.name
    case notif.event
    when "request_completed"
      who   = req&.assigned_to&.name
      parts = ["Marina: #{type} for #{boat} is complete"]
      parts << "Completed by #{who}" if who.present?
      if (url = req&.assigned_to&.venmo_url(note: "Tip for #{type}"))
        parts << "Send #{who.presence || 'them'} a tip: #{url}"
      end
      parts << "Reply STOP to opt out."
      parts.join(". ")
    when "request_cancelled"
      "Marina: #{type} for #{boat} was cancelled. Reply STOP to opt out."
    when "request_started"
      "Marina: #{type} for #{boat} has started. Reply STOP to opt out."
    when "request_submitted"
      "Marina: We received your #{type} request for #{boat}. Reply STOP to opt out."
    when "request_assigned"
      "Marina: You've been assigned a #{type} request for #{boat}. Reply STOP to opt out."
    when "public_note_added"
      "Marina: New update on your #{type} request for #{boat}. Reply STOP to opt out."
    else
      "Marina update."
    end
  end
end

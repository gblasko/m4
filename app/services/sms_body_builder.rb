class SmsBodyBuilder
  def self.for(notif)
    req = notif.request
    boat = req&.boat&.name
    type = req&.request_type&.name
    case notif.event
    when "request_completed"
      "Marina: #{type} for #{boat} is complete. Reply STOP to opt out."
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

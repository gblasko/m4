class DashboardChannel < ApplicationCable::Channel
  def subscribed
    org_id = connection.current_user&.organization_id
    stream_from "dashboard:org:#{org_id}" if org_id
  end

  def self.broadcast_create(req)
    ActionCable.server.broadcast(channel_for(req), { action: "create", id: req.id, status: req.status })
  end

  def self.broadcast_update(req)
    ActionCable.server.broadcast(channel_for(req), { action: "update", id: req.id, status: req.status })
  end

  def self.channel_for(req)
    "dashboard:org:#{req.location.organization_id}"
  end
end

class PushoverGroupSyncJob < ApplicationJob
  queue_as :default
  retry_on PushoverAdapter::Error, wait: :polynomially_longer, attempts: 3

  def perform(action:, user_id:, location_id:)
    user     = User.find_by(id: user_id)
    location = Location.find_by(id: location_id)
    return if user.nil? || location.nil?
    return if user.pushover_user_key.blank? || location.pushover_group_key.blank?

    case action.to_s
    when "add"
      PushoverAdapter.add_user_to_group(
        group_key: location.pushover_group_key,
        user_key:  user.pushover_user_key,
        memo:      "#{user.name} (#{user.role})"
      )
    when "remove"
      PushoverAdapter.remove_user_from_group(
        group_key: location.pushover_group_key,
        user_key:  user.pushover_user_key
      )
    else
      raise ArgumentError, "unknown action: #{action.inspect}"
    end
  end
end

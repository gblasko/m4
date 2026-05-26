class LocationSubscription < ApplicationRecord
  belongs_to :user
  belongs_to :location

  validates :user_id, uniqueness: { scope: :location_id }

  after_create_commit  :sync_add_to_pushover
  after_destroy_commit :sync_remove_from_pushover

  private

  def sync_add_to_pushover
    return unless syncable?
    PushoverGroupSyncJob.perform_later(action: "add", user_id: user_id, location_id: location_id)
  end

  def sync_remove_from_pushover
    return unless syncable?
    PushoverGroupSyncJob.perform_later(action: "remove", user_id: user_id, location_id: location_id)
  end

  # Skip API sync if either side hasn't supplied the key yet — admin can
  # re-save the user once the key is filled in.
  def syncable?
    user&.pushover_user_key.present? && location&.pushover_group_key.present?
  end
end

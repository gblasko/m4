class LocationHour < ApplicationRecord
  belongs_to :location

  validates :day_of_week, presence: true, inclusion: { in: 0..6 },
    uniqueness: { scope: :location_id }
  validates :open_time, :close_time, presence: true, unless: :closed?
  validate :close_after_open

  private

  def close_after_open
    return if closed? || open_time.blank? || close_time.blank?
    errors.add(:close_time, "must be after open time") unless close_time > open_time
  end
end

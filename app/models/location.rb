class Location < ApplicationRecord
  belongs_to :organization
  has_many :location_hours, dependent: :destroy
  has_many :slips, dependent: :destroy
  has_many :boats, dependent: :restrict_with_error
  has_many :requests, dependent: :restrict_with_error
  has_many :location_subscriptions, dependent: :destroy
  has_many :subscribed_staff, through: :location_subscriptions, source: :user

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :organization_id },
    format: { with: /\A[a-z0-9-]+\z/ }
  validates :timezone, presence: true
  validates :soft_cap_per_hour, numericality: { greater_than: 0 }

  scope :active, -> { where(is_active: true) }

  def hours_for(day_of_week)
    location_hours.find_by(day_of_week: day_of_week)
  end

  def open_on?(date)
    h = hours_for(date.wday)
    h.present? && !h.closed
  end

  def open_range_on(date)
    h = hours_for(date.wday)
    return nil unless h && !h.closed
    tz = ActiveSupport::TimeZone[timezone]
    open_at = tz.local(date.year, date.month, date.day, h.open_time.hour, h.open_time.min)
    close_at = tz.local(date.year, date.month, date.day, h.close_time.hour, h.close_time.min)
    (open_at..close_at)
  end

  def slot_counts_for(date)
    range = open_range_on(date)
    return {} unless range
    counts = Hash.new(0)
    requests.where(scheduled_for: range, status: %w[to_do in_progress])
            .pluck(:scheduled_for).each do |t|
      counts[t.in_time_zone(timezone).beginning_of_hour] += 1
    end
    counts
  end
end

class Request < ApplicationRecord
  STATUSES = %w[to_do in_progress completed cancelled].freeze
  LEAD_TIME = 1.hour
  MAX_HORIZON = 14.days

  belongs_to :boat
  belongs_to :customer, class_name: "User"
  belongs_to :request_type
  belongs_to :location
  belongs_to :assigned_to, class_name: "User", optional: true
  has_many :request_notes, dependent: :destroy
  has_many :notifications, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }
  validates :scheduled_for, presence: true
  validates :description, presence: true, if: -> { request_type&.requires_description }
  validate :type_compatible_with_boat
  validate :lead_time_respected, on: :create
  validate :within_location_hours
  validate :within_horizon
  validate :assignee_is_staff
  validate :assignee_for_completion

  scope :active, -> { where.not(status: "cancelled") }
  scope :open, -> { where(status: %w[to_do in_progress]) }
  scope :for_location, ->(loc) { where(location_id: loc.id) }
  scope :scheduled_on, ->(date, tz) {
    range = (date.in_time_zone(tz).beginning_of_day..date.in_time_zone(tz).end_of_day)
    where(scheduled_for: range)
  }
  scope :sorted, -> { order(:scheduled_for, :id) }

  STATUSES.each do |s|
    define_method("#{s}?") { status == s }
  end

  def cancel!(actor:, reason: nil)
    raise "Cannot cancel completed request" if completed?
    update!(status: "cancelled", cancelled_at: Time.current, cancel_reason: reason,
            cancelled_by: actor.staff? ? "staff" : "customer")
  end

  def start!(actor:)
    raise "Request must be to_do to start" unless to_do?
    update!(status: "in_progress", started_at: Time.current,
            assigned_to: assigned_to || (actor.staff? ? actor : nil))
  end

  def complete!(actor:)
    raise "Request must be in_progress to complete" unless in_progress?
    raise "Assignee required to complete" if assigned_to.nil?
    update!(status: "completed", completed_at: Time.current)
  end

  def unstart!(actor:)
    raise "Request must be in_progress to unstart" unless in_progress?
    update!(status: "to_do", started_at: nil)
  end

  def editable?
    !completed? && !cancelled?
  end

  def in_tz
    scheduled_for.in_time_zone(location.timezone)
  end

  private

  def type_compatible_with_boat
    return unless request_type && boat
    unless request_type.applicable_to_storage?(boat.storage_type)
      errors.add(:request_type_id, "is not applicable to this boat's storage type")
    end
  end

  def lead_time_respected
    return if scheduled_for.blank?
    if scheduled_for < LEAD_TIME.from_now
      errors.add(:scheduled_for, "must be at least 1 hour from now")
    end
  end

  def within_location_hours
    return if scheduled_for.blank? || location.blank?
    date = scheduled_for.in_time_zone(location.timezone).to_date
    range = location.open_range_on(date)
    if range.nil?
      errors.add(:scheduled_for, "location is closed on this day")
    elsif !range.cover?(scheduled_for)
      errors.add(:scheduled_for, "must be within location hours")
    end
  end

  def within_horizon
    return if scheduled_for.blank?
    if scheduled_for > MAX_HORIZON.from_now
      errors.add(:scheduled_for, "must be within #{MAX_HORIZON.in_days.to_i} days")
    end
  end

  def assignee_is_staff
    return if assigned_to.nil?
    errors.add(:assigned_to_id, "must be staff") unless assigned_to.staff?
  end

  def assignee_for_completion
    if status == "completed" && assigned_to.nil?
      errors.add(:assigned_to_id, "is required to complete a request")
    end
  end
end

class Notification < ApplicationRecord
  STATUSES = %w[pending sent delivered bounced failed skipped].freeze
  CHANNELS = %w[email sms push].freeze
  EVENTS = %w[
    request_submitted request_started request_completed
    request_cancelled public_note_added request_assigned
  ].freeze

  belongs_to :user
  belongs_to :request, optional: true

  validates :event, inclusion: { in: EVENTS }
  validates :channel, inclusion: { in: CHANNELS }
  validates :status, inclusion: { in: STATUSES }
  validates :to_address, presence: true

  scope :pending, -> { where(status: "pending") }
end

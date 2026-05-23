class Boat < ApplicationRecord
  STORAGE_TYPES = Slip::SLIP_TYPES

  belongs_to :owner, class_name: "User"
  belongs_to :location
  belongs_to :slip, optional: true
  has_many :requests, dependent: :restrict_with_error

  validates :name, presence: true
  validates :storage_type, inclusion: { in: STORAGE_TYPES }
  validates :year, numericality: { greater_than: 1800, less_than_or_equal_to: 2100 }, allow_nil: true
  validates :length_ft, numericality: { greater_than: 0 }, allow_nil: true
  validate :slip_matches_storage_type
  validate :slip_at_same_location

  scope :active, -> { where(is_active: true) }

  def descriptor
    [year, make, model].compact.join(" ").presence || name
  end

  private

  def slip_matches_storage_type
    return if slip.nil?
    if slip.slip_type != storage_type
      errors.add(:slip_id, "type does not match boat storage type")
    end
  end

  def slip_at_same_location
    return if slip.nil?
    errors.add(:slip_id, "must be at the same location as the boat") if slip.location_id != location_id
  end
end

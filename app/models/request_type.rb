class RequestType < ApplicationRecord
  belongs_to :organization
  has_many :requests, dependent: :restrict_with_error

  STORAGE_TYPES = Boat::STORAGE_TYPES

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :organization_id },
    format: { with: /\A[a-z0-9-]+\z/ }
  validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }
  validate :storage_types_valid

  before_validation :set_slug_from_name

  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:sort_order, :name) }

  def applicable_to_storage?(storage_type)
    applicable_storage_types.include?(storage_type.to_s)
  end

  def self.applicable_for_boat(boat)
    active.ordered.where("? = ANY (applicable_storage_types)", boat.storage_type)
  end

  private

  def set_slug_from_name
    self.slug = name.to_s.parameterize if slug.blank? && name.present?
  end

  def storage_types_valid
    bad = applicable_storage_types - STORAGE_TYPES
    errors.add(:applicable_storage_types, "invalid: #{bad.join(', ')}") if bad.any?
    errors.add(:applicable_storage_types, "must have at least one") if applicable_storage_types.empty?
  end
end

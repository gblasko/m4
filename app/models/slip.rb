class Slip < ApplicationRecord
  SLIP_TYPES = %w[dry in_water].freeze

  belongs_to :location
  has_many :boats, dependent: :nullify

  validates :label, presence: true, uniqueness: { scope: :location_id }
  validates :slip_type, inclusion: { in: SLIP_TYPES }

  scope :active, -> { where(is_active: true) }
end

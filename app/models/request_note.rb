class RequestNote < ApplicationRecord
  VISIBILITIES = %w[public private].freeze

  belongs_to :request
  belongs_to :author, class_name: "User"

  validates :body, presence: true
  validates :visibility, inclusion: { in: VISIBILITIES }
  validate :customer_cannot_create_private

  scope :public_notes, -> { where(visibility: "public") }
  scope :private_notes, -> { where(visibility: "private") }

  def public?
    visibility == "public"
  end

  private

  def customer_cannot_create_private
    return if author.nil?
    if author.customer? && visibility == "private"
      errors.add(:visibility, "customers cannot create private notes")
    end
  end
end

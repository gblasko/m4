class Organization < ApplicationRecord
  has_many :users, dependent: :restrict_with_error
  has_many :locations, dependent: :restrict_with_error
  has_many :request_types, dependent: :restrict_with_error
  has_many :audit_logs, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
    format: { with: /\A[a-z0-9-]+\z/, message: "lowercase letters, numbers, hyphens" }
end

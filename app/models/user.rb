class User < ApplicationRecord
  ROLES = { manager: 0, helper: 1, customer: 2 }.freeze
  enum :role, ROLES

  # Password is optional — most users sign in via magic link / SMS code.
  # Only the seeded admin (and any user who explicitly sets one) has a password.
  has_secure_password validations: false

  DEFAULT_PREFS = {
    "request_submitted"  => { "email" => true,  "sms" => false },
    "request_started"    => { "email" => true,  "sms" => false },
    "request_completed"  => { "email" => true,  "sms" => true  },
    "request_cancelled"  => { "email" => true,  "sms" => true  },
    "public_note_added"  => { "email" => true,  "sms" => false },
    "request_assigned"   => { "email" => true,  "sms" => false }
  }.freeze

  belongs_to :organization
  has_many :auth_tokens, dependent: :destroy
  has_many :sessions, dependent: :destroy
  has_many :boats, foreign_key: :owner_id, dependent: :restrict_with_error
  has_many :customer_requests, class_name: "Request", foreign_key: :customer_id, dependent: :restrict_with_error
  has_many :assigned_requests, class_name: "Request", foreign_key: :assigned_to_id, dependent: :nullify
  has_many :notifications, dependent: :destroy

  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true,
    uniqueness: { scope: :organization_id, case_sensitive: false, allow_blank: true }
  validates :phone, format: { with: /\A\+?[0-9\s().-]{7,20}\z/ }, allow_blank: true,
    uniqueness: { scope: :organization_id, allow_blank: true }
  validate :email_or_phone_present

  before_save :normalize_phone
  before_save :normalize_email
  after_initialize :set_default_prefs, if: :new_record?

  scope :staff, -> { where(role: [roles[:manager], roles[:helper]]) }
  scope :active, -> { where(is_active: true) }

  def staff?
    manager? || helper?
  end

  def prefers?(event, channel)
    pref = (notification_prefs.presence || DEFAULT_PREFS).dig(event.to_s, channel.to_s)
    pref.nil? ? true : !!pref
  end

  def display_contact
    email.presence || phone
  end

  def self.lookup_by_login(identifier)
    return nil if identifier.blank?
    if identifier.include?("@")
      find_by(email: identifier.downcase.strip)
    else
      digits = identifier.gsub(/\D/, "")
      where("regexp_replace(coalesce(phone,''), '\\D', '', 'g') = ?", digits).first
    end
  end

  private

  def email_or_phone_present
    if email.blank? && phone.blank?
      errors.add(:base, "Email or phone is required")
    end
  end

  def normalize_phone
    self.phone = phone.to_s.gsub(/\s+/, " ").strip if phone.present?
  end

  def normalize_email
    self.email = email.to_s.downcase.strip if email.present?
  end

  def set_default_prefs
    self.notification_prefs = DEFAULT_PREFS.deep_dup if notification_prefs.blank?
  end
end

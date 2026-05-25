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

  # E.164: leading +, country code (1–3 digits, no leading 0), national number,
  # total 8–15 digits. Stored canonically — Quo (OpenPhone) requires this format.
  E164_FORMAT = /\A\+[1-9]\d{7,14}\z/.freeze

  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true,
    uniqueness: { scope: :organization_id, case_sensitive: false, allow_blank: true }
  validates :phone, format: { with: E164_FORMAT, message: "must be a valid phone number" },
    allow_blank: true,
    uniqueness: { scope: :organization_id, allow_blank: true }
  validate :email_or_phone_present

  before_validation :normalize_phone
  before_validation :normalize_email
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
      # Stored phones are E.164 ("+15551234567"); a 10-digit input gets +1 prepended.
      digits = "1#{digits}" if digits.length == 10
      where("regexp_replace(coalesce(phone,''), '\\D', '', 'g') = ?", digits).first
    end
  end

  private

  def email_or_phone_present
    if email.blank? && phone.blank?
      errors.add(:base, "Email or phone is required")
    end
  end

  # Coerce loose input ("(555) 123-4567", "555.123.4567", "1-555-123-4567")
  # to E.164. Defaults missing country code to +1 (US/CA). Leaves the value
  # untouched if it can't be parsed so validation surfaces a clear error.
  def normalize_phone
    return if phone.blank?
    raw = phone.to_s.strip
    if raw.start_with?("+")
      self.phone = "+" + raw[1..].gsub(/\D/, "")
      return
    end
    digits = raw.gsub(/\D/, "")
    self.phone =
      case digits.length
      when 10 then "+1#{digits}"          # US/CA local
      when 11 then "+#{digits}"           # US/CA with leading 1, or other +1 country
      when 7..15 then "+#{digits}"        # international without +
      else raw                            # leave as-is; validator will reject
      end
  end

  def normalize_email
    self.email = email.to_s.downcase.strip if email.present?
  end

  def set_default_prefs
    self.notification_prefs = DEFAULT_PREFS.deep_dup if notification_prefs.blank?
  end
end

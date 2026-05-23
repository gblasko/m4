class AuthToken < ApplicationRecord
  belongs_to :user

  CHANNELS = %w[email sms].freeze
  TTL = 15.minutes

  validates :channel, inclusion: { in: CHANNELS }
  validates :expires_at, presence: true

  scope :active, -> { where(used_at: nil).where("expires_at > ?", Time.current) }

  def self.generate!(user:, channel:, ip: nil, ua: nil)
    raw = SecureRandom.urlsafe_base64(32)
    code = format("%06d", SecureRandom.random_number(1_000_000))
    create!(
      user: user,
      token_digest: digest(raw),
      short_code: channel == "sms" ? code : nil,
      channel: channel,
      expires_at: TTL.from_now,
      ip_address: ip,
      user_agent: ua
    )
    [raw, code]
  end

  def self.consume_by_token(raw_token)
    return nil if raw_token.blank?
    tok = active.find_by(token_digest: digest(raw_token))
    return nil unless tok
    tok.update!(used_at: Time.current)
    tok.user
  end

  def self.consume_by_code(user:, code:)
    return nil if user.nil? || code.blank?
    tok = active.where(user: user, channel: "sms").order(created_at: :desc).first
    return nil unless tok && ActiveSupport::SecurityUtils.secure_compare(tok.short_code.to_s, code.to_s)
    tok.update!(used_at: Time.current)
    tok.user
  end

  def self.digest(raw)
    Digest::SHA256.hexdigest(raw)
  end
end

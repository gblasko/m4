class Session < ApplicationRecord
  belongs_to :user

  ROLLING_TTL = 30.days
  ABSOLUTE_TTL = 60.days

  scope :active, -> {
    where(revoked_at: nil)
      .where("expires_at > ?", Time.current)
      .where("absolute_expires_at > ?", Time.current)
  }

  def self.start!(user:, ip: nil, ua: nil)
    raw = SecureRandom.urlsafe_base64(48)
    create!(
      user: user,
      token_digest: Digest::SHA256.hexdigest(raw),
      ip_address: ip,
      user_agent: ua,
      last_seen_at: Time.current,
      expires_at: ROLLING_TTL.from_now,
      absolute_expires_at: ABSOLUTE_TTL.from_now
    )
    raw
  end

  def self.find_active(raw)
    return nil if raw.blank?
    active.find_by(token_digest: Digest::SHA256.hexdigest(raw))
  end

  def touch_rolling!
    update_columns(
      last_seen_at: Time.current,
      expires_at: [Time.current + ROLLING_TTL, absolute_expires_at].min
    )
  end

  def revoke!
    update!(revoked_at: Time.current)
  end
end

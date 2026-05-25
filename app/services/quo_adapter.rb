require "net/http"
require "uri"
require "json"

# Quo (formerly OpenPhone) public API client for outbound SMS.
# Endpoint:  POST https://api.openphone.com/v1/messages
# Auth:      Authorization: <api-key>  (raw key, no "Bearer" prefix)
# Docs:      https://www.quo.com/docs/mdx/api-reference/messages/send-a-text-message
class QuoAdapter
  ENDPOINT = "https://api.openphone.com/v1/messages".freeze
  MAX_CONTENT = 1600

  # Send a single SMS to one recipient.
  #
  # Returns the Quo message id (e.g. "AC123abc") on success.
  # If QUO_API_KEY / QUO_FROM are unset (local dev without creds), logs the
  # would-be send and returns a stub id so the rest of the pipeline keeps working.
  def self.send_sms(to:, body:)
    api_key = ENV["QUO_API_KEY"]
    from    = ENV["QUO_FROM"] # E.164 number ("+15555555555") OR a Quo PN id ("PN123abc")

    if api_key.blank? || from.blank?
      Rails.logger.info "[QuoAdapter] (no creds) would send to #{to}: #{body}"
      return "stub-sms-#{SecureRandom.hex(8)}"
    end

    uri = URI(ENDPOINT)
    req = Net::HTTP::Post.new(uri)
    req["Authorization"] = api_key
    req["Content-Type"]  = "application/json"
    req["Accept"]        = "application/json"
    req.body = {
      content: truncate(body),
      from:    from,
      to:      [normalize_e164(to)]
    }.to_json

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |h| h.request(req) }
    raise "Quo error: #{res.code} #{res.body}" unless res.code.start_with?("2")
    JSON.parse(res.body).dig("data", "id")
  end

  # Quo requires E.164. Users' phone numbers in the DB might be loosely
  # formatted (e.g. "555-010-0001" or "(555) 010-0001"); normalize them.
  # Defaults missing country code to +1 (US/CA).
  def self.normalize_e164(phone)
    raw = phone.to_s.strip
    return raw if raw.start_with?("+")
    digits = raw.gsub(/\D/, "")
    return "+#{digits}" if digits.length >= 11
    "+1#{digits}"
  end

  def self.truncate(body)
    body.to_s[0, MAX_CONTENT]
  end
end

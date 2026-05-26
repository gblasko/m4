require "net/http"
require "uri"
require "json"

# Pushover API client. Docs: https://pushover.net/api
#
# Auth model:
#   - PUSHOVER_APP_API_KEY identifies *our* Pushover application
#   - Each staff member has their own user key (paste-in via admin form)
#   - Each location maps to a Pushover delivery group key
#
# When the app key isn't set (local dev without creds), every call is stubbed
# so the rest of the pipeline keeps working — same pattern as ResendAdapter
# and QuoAdapter.
class PushoverAdapter
  MESSAGES_ENDPOINT      = "https://api.pushover.net/1/messages.json".freeze
  GROUPS_BASE            = "https://api.pushover.net/1/groups".freeze
  VALIDATE_USER_ENDPOINT = "https://api.pushover.net/1/users/validate.json".freeze

  class Error < StandardError; end

  # Send a push to a group (or user) key. Returns the Pushover receipt id.
  def self.send_message(group_key:, message:, title: nil, url: nil)
    return stub("send_message to=#{group_key} #{title}: #{message}") if app_key.blank?

    payload = { token: app_key, user: group_key, message: message }
    payload[:title] = title if title.present?
    payload[:url]   = url   if url.present?

    body = post(MESSAGES_ENDPOINT, payload, context: "send_message")
    body["request"] # Pushover returns a "request" UUID on success
  end

  # Add a user key to a group. Pushover returns status:0 if the user is
  # already a member; treat that as success so this stays idempotent.
  def self.add_user_to_group(group_key:, user_key:, memo: nil)
    return stub("add_user_to_group group=#{group_key} user=#{user_key}") if app_key.blank?

    payload = { token: app_key, user: user_key }
    payload[:memo] = memo if memo.present?

    post("#{GROUPS_BASE}/#{group_key}/add_user.json", payload,
         context: "add_user_to_group",
         ignore_errors: [/already exists/i, /already.*member/i])
    true
  end

  # Remove a user from a group. Idempotent — "not in group" is a success.
  def self.remove_user_from_group(group_key:, user_key:)
    return stub("remove_user_from_group group=#{group_key} user=#{user_key}") if app_key.blank?

    post("#{GROUPS_BASE}/#{group_key}/remove_user.json",
         { token: app_key, user: user_key },
         context: "remove_user_from_group",
         ignore_errors: [/not.*found/i, /not.*member/i, /invalid user/i])
    true
  end

  # Returns true if Pushover recognizes the user key, false otherwise.
  # In stub mode (no app key) returns true — local dev shouldn't block on this.
  def self.validate_user(user_key:)
    return true if app_key.blank?
    return false if user_key.blank?

    uri  = URI(VALIDATE_USER_ENDPOINT)
    req  = Net::HTTP::Post.new(uri)
    req.set_form_data(token: app_key, user: user_key)
    res  = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |h| h.request(req) }
    body = safe_parse(res.body)
    body.is_a?(Hash) && body["status"].to_i == 1
  rescue => e
    Rails.logger.warn "[PushoverAdapter] validate_user error: #{e.message}"
    false
  end

  def self.app_key
    ENV["PUSHOVER_APP_API_KEY"].to_s.strip.presence
  end

  def self.stub(detail)
    Rails.logger.info "[PushoverAdapter] (no key) would #{detail}"
    "stub-push-#{SecureRandom.hex(8)}"
  end

  def self.post(endpoint, params, context:, ignore_errors: [])
    uri = URI(endpoint)
    req = Net::HTTP::Post.new(uri)
    req.set_form_data(params)

    res  = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |h| h.request(req) }
    body = safe_parse(res.body)

    if body.is_a?(Hash) && body["status"].to_i == 1
      return body
    end

    errors = Array(body.is_a?(Hash) ? body["errors"] : nil).join(", ")
    if ignore_errors.any? { |re| errors.match?(re) }
      Rails.logger.info "[PushoverAdapter] #{context}: ignoring expected error: #{errors}"
      return body
    end

    Rails.logger.error "[PushoverAdapter] #{context} failed: resp=#{res.code} #{res.body}"
    raise Error, "Pushover #{context} error: #{res.code} #{errors.presence || res.body}"
  end

  def self.safe_parse(body)
    JSON.parse(body.to_s)
  rescue JSON::ParserError
    {}
  end
end

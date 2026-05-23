require "net/http"
require "uri"
require "json"

class TwilioAdapter
  def self.send_sms(to:, body:)
    sid   = ENV["TWILIO_ACCOUNT_SID"]
    token = ENV["TWILIO_AUTH_TOKEN"]
    from  = ENV["TWILIO_FROM_NUMBER"]

    if sid.blank? || token.blank? || from.blank?
      Rails.logger.info "[TwilioAdapter] (no creds) would send to #{to}: #{body}"
      return "stub-sms-#{SecureRandom.hex(8)}"
    end

    uri = URI("https://api.twilio.com/2010-04-01/Accounts/#{sid}/Messages.json")
    req = Net::HTTP::Post.new(uri)
    req.basic_auth(sid, token)
    req.set_form_data("To" => to, "From" => from, "Body" => body)
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |h| h.request(req) }
    raise "Twilio error: #{res.code} #{res.body}" unless res.code.start_with?("2")
    JSON.parse(res.body)["sid"]
  end
end

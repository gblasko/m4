require "net/http"
require "uri"
require "json"

class ResendAdapter
  ENDPOINT = "https://api.resend.com/emails".freeze

  def self.send_email(mail)
    api_key = ENV["RESEND_API_KEY"]
    if api_key.blank?
      Rails.logger.info "[ResendAdapter] (no key) would send: #{mail.subject} -> #{mail.to.join(',')}"
      return "stub-#{SecureRandom.hex(8)}"
    end

    uri = URI(ENDPOINT)
    body = {
      from: from_header(mail),
      to: Array(mail.to),
      subject: mail.subject,
      html: mail.html_part&.body&.to_s.presence || mail.body.to_s,
      text: mail.text_part&.body&.to_s
    }.compact

    req = Net::HTTP::Post.new(uri)
    req["Authorization"] = "Bearer #{api_key}"
    req["Content-Type"] = "application/json"
    req.body = body.to_json

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |h| h.request(req) }
    unless res.code.start_with?("2")
      Rails.logger.error "[ResendAdapter] send failed: from=#{body[:from].inspect} to=#{body[:to].inspect} subject=#{body[:subject].inspect} resp=#{res.code} #{res.body}"
      raise "Resend error: #{res.code} #{res.body}"
    end
    JSON.parse(res.body)["id"]
  end

  # Prefer the fully-formatted header value ("Name <addr@host>" or "addr@host")
  # so display names survive the trip to Resend. Fall back to the bare address
  # if the header is missing for any reason.
  def self.from_header(mail)
    mail[:from]&.formatted&.first.to_s.strip.presence || mail.from&.first.to_s.strip
  end
end

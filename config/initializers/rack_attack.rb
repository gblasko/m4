class Rack::Attack
  ### Throttles for /auth/login
  throttle("auth/login/ip", limit: 20, period: 1.hour) do |req|
    req.ip if req.path == "/auth/login" && req.post?
  end

  throttle("auth/login/identifier", limit: 5, period: 1.hour) do |req|
    if req.path == "/auth/login" && req.post?
      req.params["identifier"].to_s.downcase.strip.presence
    end
  end

  throttle("auth/verify/ip", limit: 60, period: 1.hour) do |req|
    req.ip if req.path == "/auth/verify"
  end

  self.throttled_responder = lambda do |env|
    match_data = env["rack.attack.match_data"]
    headers = {
      "Content-Type" => "text/html",
      "Retry-After" => match_data[:period].to_s
    }
    [429, headers, ["Too many attempts. Please try again later.\n"]]
  end
end

Rails.application.config.middleware.use Rack::Attack

require "rails_helper"

RSpec.describe "Auth", type: :request do
  it "GET /login renders" do
    get "/login"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Marina")
  end

  it "POST /auth/login is generic (no user enumeration)" do
    post "/auth/login", params: { identifier: "nobody@nope.com" }
    expect(response).to redirect_to(login_check_path(channel: "email"))
  end

  it "magic link signs in user" do
    user = create(:user, :manager)
    raw = SecureRandom.urlsafe_base64(32)
    AuthToken.create!(user: user, token_digest: AuthToken.digest(raw),
                      channel: "email", expires_at: 10.minutes.from_now)
    get "/auth/verify", params: { token: raw }
    expect(response).to redirect_to("/dashboard")
    follow_redirect!
    expect(response).to have_http_status(:ok)
  end
end

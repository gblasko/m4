require "rails_helper"

RSpec.describe "Admin authorization", type: :request do
  let(:org) { create(:organization) }
  let(:manager) { create(:user, :manager, organization: org) }
  let(:customer) { create(:user, :customer, organization: org) }

  def sign_in_as(user)
    raw = SecureRandom.urlsafe_base64(32)
    AuthToken.create!(user: user, token_digest: AuthToken.digest(raw),
                      channel: "email", expires_at: 10.minutes.from_now)
    get "/auth/verify", params: { token: raw }
  end

  it "customer gets 403 on /admin" do
    sign_in_as(customer)
    get "/admin"
    expect(response).to have_http_status(:forbidden)
  end

  it "manager can access /admin" do
    sign_in_as(manager)
    get "/admin"
    expect(response).to have_http_status(:ok)
  end

  it "unauthenticated users get redirected" do
    get "/admin"
    expect(response).to redirect_to(login_path)
  end
end

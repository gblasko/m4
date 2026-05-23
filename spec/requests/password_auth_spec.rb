require "rails_helper"

RSpec.describe "Password auth", type: :request do
  let(:user) { create(:user, :manager, email: "admin@example.com") }

  before { user.update!(password: "Correct-Horse-Battery-Staple") }

  it "signs in with correct email + password" do
    post "/auth/login", params: { identifier: "admin@example.com", password: "Correct-Horse-Battery-Staple" }
    expect(response).to redirect_to("/dashboard")
    follow_redirect!
    expect(response).to have_http_status(:ok)
  end

  it "returns generic error on wrong password" do
    post "/auth/login", params: { identifier: "admin@example.com", password: "wrong" }
    expect(response).to redirect_to(login_path)
    expect(flash[:alert]).to match(/incorrect/i)
  end

  it "returns generic error on unknown email when password supplied (no enumeration)" do
    post "/auth/login", params: { identifier: "nobody@nope.com", password: "anything" }
    expect(response).to redirect_to(login_path)
    expect(flash[:alert]).to match(/incorrect/i)
  end

  it "falls through to magic-link flow when password is blank" do
    post "/auth/login", params: { identifier: "admin@example.com" }
    expect(response).to redirect_to(login_check_path(channel: "email"))
  end

  it "users without a password_digest can't sign in by password" do
    user_no_pw = create(:user, :manager, email: "nopw@example.com")
    post "/auth/login", params: { identifier: "nopw@example.com", password: "anything" }
    expect(response).to redirect_to(login_path)
    expect(flash[:alert]).to match(/incorrect/i)
  end
end

require "rails_helper"

RSpec.describe "Request status (XHR)", type: :request do
  let(:org) { create(:organization) }
  let(:manager) { create(:user, :manager, organization: org) }
  let(:loc) { create(:location, organization: org) }
  let(:customer) { create(:user, :customer, organization: org) }
  let(:boat) { create(:boat, owner: customer, location: loc, storage_type: "in_water") }
  let(:rt) { create(:request_type, organization: org, applicable_storage_types: %w[in_water]) }
  let!(:req) do
    tz = ActiveSupport::TimeZone[loc.timezone]
    sched = tz.now.tomorrow.change(hour: 10, min: 0)
    create(:request, boat: boat, customer: customer, location: loc, request_type: rt, scheduled_for: sched)
  end

  def sign_in_as(user)
    raw = SecureRandom.urlsafe_base64(32)
    AuthToken.create!(user: user, token_digest: AuthToken.digest(raw),
                      channel: "email", expires_at: 10.minutes.from_now)
    get "/auth/verify", params: { token: raw }
  end

  it "returns 204 for a valid transition over XHR" do
    sign_in_as(manager)
    patch "/requests/#{req.id}/status",
          params: { to: "in_progress" },
          headers: { "Accept" => "application/json", "X-Requested-With" => "XMLHttpRequest" }
    expect(response).to have_http_status(:no_content)
    expect(req.reload.status).to eq("in_progress")
  end

  it "returns JSON error 422 for an invalid transition" do
    sign_in_as(manager)
    # Cannot unstart something that's still to_do
    patch "/requests/#{req.id}/status",
          params: { to: "to_do" },
          headers: { "Accept" => "application/json", "X-Requested-With" => "XMLHttpRequest" }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)["error"]).to be_present
    expect(req.reload.status).to eq("to_do")
  end

  it "still redirects with flash for HTML callers" do
    sign_in_as(manager)
    patch "/requests/#{req.id}/status", params: { to: "in_progress" }
    expect(response).to redirect_to(request_path(req))
  end
end

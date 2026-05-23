require "rails_helper"

RSpec.describe "Admin::Requests (staff on-behalf creation)", type: :request do
  let(:org) { create(:organization) }
  let(:manager) { create(:user, :manager, organization: org) }
  let(:helper)  { create(:user, :helper, organization: org) }
  let(:customer) { create(:user, :customer, organization: org) }
  let(:other_customer) { create(:user, :customer, organization: org) }
  let(:loc) { create(:location, organization: org) }
  let(:boat) { create(:boat, owner: customer, location: loc, storage_type: "in_water") }
  let(:rt) { create(:request_type, organization: org, applicable_storage_types: %w[in_water]) }

  def sign_in_as(user)
    raw = SecureRandom.urlsafe_base64(32)
    AuthToken.create!(user: user, token_digest: AuthToken.digest(raw),
                      channel: "email", expires_at: 10.minutes.from_now)
    get "/auth/verify", params: { token: raw }
  end

  it "managers and helpers can both reach the form" do
    sign_in_as(manager)
    get "/admin/requests/new"
    expect(response).to have_http_status(:ok)

    sign_in_as(helper)
    get "/admin/requests/new"
    expect(response).to have_http_status(:ok)
  end

  it "customers cannot reach the form" do
    sign_in_as(customer)
    get "/admin/requests/new"
    expect(response).to have_http_status(:forbidden)
  end

  it "renders only the customer step when none selected" do
    sign_in_as(manager)
    get "/admin/requests/new"
    expect(response.body).to include('name="customer_id"')
    expect(response.body).not_to include('name="boat_id"')
  end

  it "reveals the boat step after picking a customer with boats" do
    boat # ensure created
    sign_in_as(manager)
    get "/admin/requests/new", params: { customer_id: customer.id }
    expect(response.body).to include('name="boat_id"')
  end

  it "creates a request on behalf of the customer, audited as staff_create" do
    boat; rt
    sign_in_as(manager)

    tz = ActiveSupport::TimeZone[loc.timezone]
    sched = tz.now.tomorrow.change(hour: 10, min: 0)

    expect {
      post "/admin/requests", params: {
        request: {
          customer_id: customer.id,
          boat_id: boat.id,
          request_type_id: rt.id,
          scheduled_for: sched.iso8601,
          description: "Phoned in"
        }
      }
    }.to change(Request, :count).by(1)

    req = Request.last
    expect(req.customer).to eq(customer)
    expect(req.boat).to eq(boat)
    expect(response).to redirect_to(request_path(req))

    audit = AuditLog.find_by(auditable: req, action: "staff_create")
    expect(audit).to be_present
    expect(audit.actor).to eq(manager)
  end

  it "rejects creating for a boat that doesn't belong to the chosen customer" do
    boat; rt
    sign_in_as(manager)
    expect {
      post "/admin/requests", params: {
        request: {
          customer_id: other_customer.id,
          boat_id: boat.id,
          request_type_id: rt.id,
          scheduled_for: 2.hours.from_now.iso8601,
          description: "x"
        }
      }
    }.not_to change(Request, :count)
  end
end

require "rails_helper"

RSpec.describe "Admin::Customers", type: :request do
  let(:org) { create(:organization) }
  let(:manager) { create(:user, :manager, organization: org) }
  let(:customer) do
    create(:user, :customer, :with_phone, organization: org,
      name: "Pat Customer", email: "pat@example.com")
  end

  def sign_in_as(user)
    raw = SecureRandom.urlsafe_base64(32)
    AuthToken.create!(user: user, token_digest: AuthToken.digest(raw),
                      channel: "email", expires_at: 10.minutes.from_now)
    get "/auth/verify", params: { token: raw }
  end

  describe "GET /admin/customers/new" do
    before { sign_in_as(manager) }

    # Regression: form_with model: [:admin, customer] used to generate
    # action="/admin/users" because customer is a User instance — the Staff
    # endpoint then forced unknown roles to :helper, turning every new
    # customer into a staff member.
    it "renders a form that POSTs to /admin/customers (not /admin/users)" do
      get "/admin/customers/new"
      expect(response.body).to include('action="/admin/customers"')
      expect(response.body).not_to include('action="/admin/users"')
    end

    it "renders the edit form with action /admin/customers/:id" do
      cust = create(:user, :customer, organization: org)
      get edit_admin_customer_path(cust)
      expect(response.body).to include("action=\"/admin/customers/#{cust.id}\"")
    end
  end

  describe "POST /admin/customers" do
    before { sign_in_as(manager) }

    it "creates a user with role: customer" do
      post "/admin/customers", params: {
        user: { name: "New Customer", email: "new@example.com", phone: "555-111-2222", is_active: "1" }
      }
      user = User.find_by(email: "new@example.com")
      expect(user).to be_present
      expect(user.role).to eq("customer")
      expect(user.phone).to eq("+15551112222")
    end

    it "ignores a tampered role param (stays customer)" do
      post "/admin/customers", params: {
        user: { name: "Tamper", email: "tamper@example.com", phone: "555-111-3333",
                is_active: "1", role: "manager" }
      }
      user = User.find_by(email: "tamper@example.com")
      expect(user.role).to eq("customer")
    end

    it "does not appear under /admin/users (staff list)" do
      post "/admin/customers", params: {
        user: { name: "Staff Filter Test", email: "filter@example.com",
                phone: "555-111-4444", is_active: "1" }
      }
      get "/admin/users"
      expect(response.body).not_to include("Staff Filter Test")
    end
  end

  describe "POST /admin/customers/:id/invite" do
    before { sign_in_as(manager) }

    it "emails an invite when channel=email" do
      expect {
        post invite_admin_customer_path(customer), params: { channel: "email" }
      }.to change { AuthToken.where(user: customer, channel: "email").count }.by(1)
        .and have_enqueued_mail(AuthMailer, :invite)
      expect(response).to redirect_to(admin_customer_path(customer))
      follow_redirect!
      expect(response.body).to include("Invite sent via email")
    end

    it "texts an invite when channel=sms" do
      expect {
        post invite_admin_customer_path(customer), params: { channel: "sms" }
      }.to change { AuthToken.where(user: customer, channel: "sms").count }.by(1)
        .and have_enqueued_job(SmsSenderJob)
      follow_redirect!
      expect(response.body).to include("Invite sent via sms")
    end

    it "rejects email channel for a customer without email" do
      customer.update_columns(email: nil)
      post invite_admin_customer_path(customer), params: { channel: "email" }
      follow_redirect!
      expect(response.body).to include("No email on file")
    end

    it "rejects sms channel for a customer without phone" do
      customer.update_columns(phone: nil)
      post invite_admin_customer_path(customer), params: { channel: "sms" }
      follow_redirect!
      expect(response.body).to include("No phone on file")
    end
  end
end

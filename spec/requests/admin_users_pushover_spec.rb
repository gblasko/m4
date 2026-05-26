require "rails_helper"

RSpec.describe "Admin::Users Pushover wiring", type: :request do
  include ActiveJob::TestHelper

  let(:org)     { create(:organization) }
  let(:manager) { create(:user, :manager, organization: org) }
  let(:location_a) { create(:location, organization: org, name: "Browns Bay", pushover_group_key: "g" * 30) }
  let(:location_b) { create(:location, organization: org, name: "Maxwells",   pushover_group_key: "h" * 30) }

  def sign_in_as(user)
    raw = SecureRandom.urlsafe_base64(32)
    AuthToken.create!(user: user, token_digest: AuthToken.digest(raw),
                      channel: "email", expires_at: 10.minutes.from_now)
    get "/auth/verify", params: { token: raw }
  end

  before do
    allow(PushoverAdapter).to receive(:validate_user).and_return(true)
    location_a; location_b
    sign_in_as(manager)
  end

  describe "POST /admin/users" do
    it "creates staff with a Pushover key and the selected subscriptions" do
      expect {
        post "/admin/users", params: {
          user: {
            name: "Helga Helper", email: "helga@example.com", role: "helper", is_active: "1",
            pushover_user_key: "x" * 30,
            subscribed_location_ids: [location_a.id.to_s]
          }
        }
      }.to change { User.count }.by(1)

      user = User.find_by(email: "helga@example.com")
      expect(user.pushover_user_key).to eq("x" * 30)
      expect(user.subscribed_location_ids).to contain_exactly(location_a.id)
    end

    it "rejects an invalid Pushover key reported by validate_user" do
      allow(PushoverAdapter).to receive(:validate_user).and_return(false)

      post "/admin/users", params: {
        user: {
          name: "Bad Key", email: "badkey@example.com", role: "helper", is_active: "1",
          pushover_user_key: "y" * 30
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Pushover")
      expect(User.find_by(email: "badkey@example.com")).to be_nil
    end

    it "ignores subscription ids that aren't in the current organization" do
      other_org_loc = create(:location, pushover_group_key: "z" * 30)
      post "/admin/users", params: {
        user: {
          name: "Scoped", email: "scoped@example.com", role: "helper", is_active: "1",
          pushover_user_key: "x" * 30,
          subscribed_location_ids: [other_org_loc.id.to_s, location_a.id.to_s]
        }
      }
      user = User.find_by(email: "scoped@example.com")
      expect(user.subscribed_location_ids).to contain_exactly(location_a.id)
    end
  end

  describe "POST /admin/users/:id/test_push" do
    let(:helper) { create(:user, :helper, organization: org, pushover_user_key: "x" * 30) }

    it "sends a push directly to the user's pushover_user_key" do
      expect(PushoverAdapter).to receive(:send_message)
        .with(hash_including(group_key: helper.pushover_user_key))
        .and_return("rcpt-1")

      post "/admin/users/#{helper.id}/test_push"
      expect(response).to redirect_to(edit_admin_user_path(helper))
      follow_redirect!
      expect(response.body).to include("Test push sent")
    end

    it "errors when no key is on file" do
      keyless = create(:user, :helper, organization: org)
      post "/admin/users/#{keyless.id}/test_push"
      follow_redirect!
      expect(response.body).to include("No Pushover user key")
    end

    it "surfaces Pushover errors in the flash" do
      allow(PushoverAdapter).to receive(:send_message)
        .and_raise(PushoverAdapter::Error.new("user has no active devices"))
      post "/admin/users/#{helper.id}/test_push"
      follow_redirect!
      expect(response.body).to include("Pushover refused the test push")
      expect(response.body).to include("no active devices")
    end
  end

  describe "POST /admin/users/:id/resync_pushover" do
    let(:helper) { create(:user, :helper, organization: org, pushover_user_key: "x" * 30) }

    it "re-runs add_user_to_group for every subscribed location" do
      helper.location_subscriptions.create!(location: location_a)
      helper.location_subscriptions.create!(location: location_b)

      expect(PushoverAdapter).to receive(:add_user_to_group)
        .with(hash_including(group_key: location_a.pushover_group_key, user_key: helper.pushover_user_key))
      expect(PushoverAdapter).to receive(:add_user_to_group)
        .with(hash_including(group_key: location_b.pushover_group_key, user_key: helper.pushover_user_key))

      post "/admin/users/#{helper.id}/resync_pushover"
      follow_redirect!
      expect(response.body).to include("Browns Bay: ✓")
      expect(response.body).to include("Maxwells: ✓")
    end

    it "reports per-location failure rather than raising" do
      helper.location_subscriptions.create!(location: location_a)
      allow(PushoverAdapter).to receive(:add_user_to_group)
        .and_raise(PushoverAdapter::Error.new("invalid user key"))

      post "/admin/users/#{helper.id}/resync_pushover"
      follow_redirect!
      expect(response.body).to include("Browns Bay: ✗")
      expect(response.body).to include("invalid user key")
    end
  end

  describe "PATCH /admin/users/:id" do
    let(:helper) { create(:user, :helper, organization: org, pushover_user_key: "x" * 30) }

    it "syncs add/remove when subscriptions change" do
      helper.subscribed_location_ids = [location_a.id]
      clear_enqueued_jobs

      expect {
        patch "/admin/users/#{helper.id}", params: {
          user: {
            name: helper.name, email: helper.email, role: "helper", is_active: "1",
            pushover_user_key: helper.pushover_user_key,
            subscribed_location_ids: [location_b.id.to_s]
          }
        }
      }.to have_enqueued_job(PushoverGroupSyncJob).with(action: "add",    user_id: helper.id, location_id: location_b.id)
        .and have_enqueued_job(PushoverGroupSyncJob).with(action: "remove", user_id: helper.id, location_id: location_a.id)

      expect(helper.reload.subscribed_location_ids).to contain_exactly(location_b.id)
    end
  end
end

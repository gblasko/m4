require "rails_helper"

RSpec.describe LocationSubscription do
  include ActiveJob::TestHelper

  let(:org) { create(:organization) }
  let(:location_with_key) { create(:location, organization: org, pushover_group_key: "g" * 30) }
  let(:helper_with_key) { create(:user, :helper, organization: org, pushover_user_key: "u" * 30) }

  it "enqueues an add sync job after create when both keys are present" do
    expect {
      described_class.create!(user: helper_with_key, location: location_with_key)
    }.to have_enqueued_job(PushoverGroupSyncJob)
      .with(action: "add", user_id: helper_with_key.id, location_id: location_with_key.id)
  end

  it "enqueues a remove sync job after destroy" do
    sub = described_class.create!(user: helper_with_key, location: location_with_key)
    clear_enqueued_jobs
    expect { sub.destroy! }
      .to have_enqueued_job(PushoverGroupSyncJob)
      .with(action: "remove", user_id: helper_with_key.id, location_id: location_with_key.id)
  end

  it "skips sync when the user has no pushover_user_key" do
    plain_helper = create(:user, :helper, organization: org)
    expect {
      described_class.create!(user: plain_helper, location: location_with_key)
    }.not_to have_enqueued_job(PushoverGroupSyncJob)
  end

  it "skips sync when the location has no pushover_group_key" do
    location = create(:location, organization: org)
    expect {
      described_class.create!(user: helper_with_key, location: location)
    }.not_to have_enqueued_job(PushoverGroupSyncJob)
  end

  it "enforces uniqueness of (user, location)" do
    described_class.create!(user: helper_with_key, location: location_with_key)
    dup = described_class.new(user: helper_with_key, location: location_with_key)
    expect(dup).not_to be_valid
  end
end

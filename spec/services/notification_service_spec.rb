require "rails_helper"

RSpec.describe NotificationService do
  include ActiveJob::TestHelper

  describe ".dispatch_for_location" do
    let(:org) { create(:organization) }
    let(:location_with_key) do
      create(:location, organization: org, pushover_group_key: "g" * 30)
    end
    let(:location_without_key) { create(:location, organization: org) }

    let(:customer) { create(:user, :customer, organization: org) }
    let(:boat) do
      create(:boat,
             owner: customer,
             location: location_with_key,
             slip: create(:slip, location: location_with_key))
    end
    # 10am tomorrow in the location's tz — guaranteed to be inside location hours
    # (factory seeds 07:00-18:00 every day) regardless of when the suite runs.
    let(:in_hours) { (Time.current + 1.day).in_time_zone("America/Chicago").change(hour: 10) }
    let(:request_row) { create(:request, boat: boat, location: location_with_key, scheduled_for: in_hours) }

    it "enqueues PushoverNotificationJob when location has a group key" do
      expect {
        described_class.dispatch_for_location(event: "request_submitted", request: request_row)
      }.to have_enqueued_job(PushoverNotificationJob)
        .with(event: "request_submitted", request_id: request_row.id)
    end

    it "is a no-op when the location has no group key" do
      boat_no_key = create(:boat,
                           owner: customer,
                           location: location_without_key,
                           slip: create(:slip, location: location_without_key))
      req = create(:request, boat: boat_no_key, location: location_without_key, scheduled_for: in_hours)

      expect {
        described_class.dispatch_for_location(event: "request_submitted", request: req)
      }.not_to have_enqueued_job(PushoverNotificationJob)
    end
  end
end

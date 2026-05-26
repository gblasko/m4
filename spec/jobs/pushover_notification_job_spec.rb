require "rails_helper"

RSpec.describe PushoverNotificationJob do
  let(:org) { create(:organization) }
  let(:location) { create(:location, organization: org, pushover_group_key: "g" * 30) }
  let(:customer) { create(:user, :customer, organization: org) }
  let(:boat) { create(:boat, owner: customer, location: location, slip: create(:slip, location: location)) }
  let(:in_hours) { (Time.current + 1.day).in_time_zone("America/Chicago").change(hour: 10) }
  let(:request_row) { create(:request, boat: boat, location: location, scheduled_for: in_hours) }

  it "sends a push to the location's group key" do
    expect(PushoverAdapter).to receive(:send_message).with(
      hash_including(group_key: location.pushover_group_key)
    ).and_return("rcpt")

    described_class.perform_now(event: "request_submitted", request_id: request_row.id)
  end

  it "no-ops when the location has no group key" do
    location.update!(pushover_group_key: nil)
    expect(PushoverAdapter).not_to receive(:send_message)
    described_class.perform_now(event: "request_submitted", request_id: request_row.id)
  end

  it "no-ops when the request was deleted" do
    expect(PushoverAdapter).not_to receive(:send_message)
    described_class.perform_now(event: "request_submitted", request_id: 0)
  end
end

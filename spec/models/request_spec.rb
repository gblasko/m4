require "rails_helper"

RSpec.describe Request, type: :model do
  let(:org) { create(:organization) }
  let(:loc) { create(:location, organization: org) }
  let(:customer) { create(:user, :customer, organization: org) }
  let(:boat) { create(:boat, owner: customer, location: loc, storage_type: "in_water") }
  let(:wet_type) { create(:request_type, organization: org, applicable_storage_types: %w[in_water]) }
  let(:dry_only_type) { create(:request_type, organization: org, applicable_storage_types: %w[dry]) }

  it "requires a 1-hour lead time on create" do
    req = build(:request, boat: boat, customer: customer, location: loc,
                request_type: wet_type, scheduled_for: 30.minutes.from_now)
    expect(req).not_to be_valid
    expect(req.errors[:scheduled_for].first).to match(/1 hour/)
  end

  it "rejects schedule outside location hours" do
    tz = ActiveSupport::TimeZone[loc.timezone]
    midnight = tz.local(Date.tomorrow.year, Date.tomorrow.month, Date.tomorrow.day, 23, 0)
    req = build(:request, boat: boat, customer: customer, location: loc,
                request_type: wet_type, scheduled_for: midnight)
    expect(req).not_to be_valid
    expect(req.errors[:scheduled_for]).to include(match(/hours/))
  end

  it "rejects a type that doesn't apply to the boat's storage" do
    req = build(:request, boat: boat, customer: customer, location: loc,
                request_type: dry_only_type, scheduled_for: 2.hours.from_now)
    expect(req).not_to be_valid
    expect(req.errors[:request_type_id]).to be_present
  end

  it "rejects scheduling more than 14 days out" do
    req = build(:request, boat: boat, customer: customer, location: loc,
                request_type: wet_type, scheduled_for: 20.days.from_now)
    expect(req).not_to be_valid
    expect(req.errors[:scheduled_for]).to include(match(/14 days/))
  end

  it "supports the full status flow with assignee required for completion" do
    helper = create(:user, :helper, organization: org)
    tz = ActiveSupport::TimeZone[loc.timezone]
    sched = tz.now.tomorrow.change(hour: 10, min: 0)
    req = create(:request, boat: boat, customer: customer, location: loc,
                 request_type: wet_type, scheduled_for: sched)

    req.start!(actor: helper)
    expect(req.reload.status).to eq("in_progress")

    # cannot complete without assignee
    req.update!(assigned_to: nil)
    expect { req.complete!(actor: helper) }.to raise_error(/Assignee required/)

    req.update!(assigned_to: helper)
    req.complete!(actor: helper)
    expect(req.reload.status).to eq("completed")
  end
end

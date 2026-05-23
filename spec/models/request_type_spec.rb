require "rails_helper"

RSpec.describe RequestType, type: :model do
  let(:org) { create(:organization) }

  it ".applicable_for_boat filters by storage type" do
    dry = create(:request_type, organization: org, applicable_storage_types: %w[dry])
    wet = create(:request_type, organization: org, applicable_storage_types: %w[in_water])
    both = create(:request_type, organization: org, applicable_storage_types: %w[dry in_water])
    customer = create(:user, :customer, organization: org)
    boat = create(:boat, owner: customer, storage_type: "dry",
                  location: create(:location, organization: org))

    results = RequestType.applicable_for_boat(boat).where(organization_id: org.id)
    expect(results).to include(dry, both)
    expect(results).not_to include(wet)
  end

  it "requires applicable_storage_types to be non-empty" do
    rt = build(:request_type, organization: org, applicable_storage_types: [])
    expect(rt).not_to be_valid
  end
end

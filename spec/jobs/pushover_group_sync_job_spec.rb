require "rails_helper"

RSpec.describe PushoverGroupSyncJob do
  let(:org) { create(:organization) }
  let(:location) { create(:location, organization: org, pushover_group_key: "g" * 30) }
  let(:user) { create(:user, :helper, organization: org, pushover_user_key: "u" * 30) }

  it "calls add_user_to_group when action is 'add'" do
    expect(PushoverAdapter).to receive(:add_user_to_group)
      .with(hash_including(group_key: location.pushover_group_key, user_key: user.pushover_user_key))
    described_class.perform_now(action: "add", user_id: user.id, location_id: location.id)
  end

  it "calls remove_user_from_group when action is 'remove'" do
    expect(PushoverAdapter).to receive(:remove_user_from_group)
      .with(group_key: location.pushover_group_key, user_key: user.pushover_user_key)
    described_class.perform_now(action: "remove", user_id: user.id, location_id: location.id)
  end

  it "no-ops when either key is missing" do
    user.update!(pushover_user_key: nil)
    expect(PushoverAdapter).not_to receive(:add_user_to_group)
    described_class.perform_now(action: "add", user_id: user.id, location_id: location.id)
  end
end

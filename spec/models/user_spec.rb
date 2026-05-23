require "rails_helper"

RSpec.describe User, type: :model do
  let(:org) { create(:organization) }

  describe ".lookup_by_login" do
    it "matches by email case-insensitively" do
      u = create(:user, organization: org, email: "Pat@Example.com")
      expect(User.lookup_by_login("pat@example.com")).to eq(u)
    end

    it "matches by phone digits regardless of formatting" do
      u = create(:user, :with_phone, organization: org, phone: "(555) 123-4567")
      expect(User.lookup_by_login("555-123-4567")).to eq(u)
    end
  end

  describe "#prefers?" do
    it "respects user prefs when set" do
      u = create(:user, organization: org)
      u.notification_prefs["request_completed"] = { "email" => false, "sms" => true }
      u.save!
      expect(u.prefers?("request_completed", "email")).to eq(false)
      expect(u.prefers?("request_completed", "sms")).to eq(true)
    end
  end

  it "requires email or phone" do
    u = build(:user, organization: org, email: nil, phone: nil)
    expect(u).not_to be_valid
  end
end

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

  describe "#venmo_url" do
    it "builds a pay link, stripping a leading @ and encoding the note" do
      u = build(:user, venmo_handle: "@hannah")
      expect(u.venmo_url(note: "Tip for Wash"))
        .to eq("https://venmo.com/hannah?txn=pay&note=Tip%20for%20Wash")
    end

    it "omits the note param when none is given" do
      u = build(:user, venmo_handle: "hannah")
      expect(u.venmo_url).to eq("https://venmo.com/hannah?txn=pay")
    end

    it "returns nil when no handle is set" do
      expect(build(:user, venmo_handle: nil).venmo_url(note: "x")).to be_nil
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

  describe "phone normalization" do
    it "coerces 10-digit US to E.164 with +1" do
      u = create(:user, organization: org, phone: "555-123-4567")
      expect(u.phone).to eq("+15551234567")
    end

    it "strips formatting from 11-digit input" do
      u = create(:user, organization: org, phone: "1 (555) 123-4567")
      expect(u.phone).to eq("+15551234567")
    end

    it "preserves an already-E.164 number" do
      u = create(:user, organization: org, phone: "+447400123456")
      expect(u.phone).to eq("+447400123456")
    end

    it "rejects gibberish that can't be coerced" do
      u = build(:user, organization: org, email: "x@y.com", phone: "abc")
      expect(u).not_to be_valid
      expect(u.errors[:phone]).to include("must be a valid phone number")
    end

    it "rejects too-short input" do
      u = build(:user, organization: org, email: "x@y.com", phone: "12345")
      expect(u).not_to be_valid
    end
  end
end

require "rails_helper"

RSpec.describe QuoAdapter do
  describe ".normalize_e164" do
    it "passes through E.164 already" do
      expect(described_class.normalize_e164("+15551234567")).to eq("+15551234567")
    end

    it "assumes +1 country code for 10-digit US numbers" do
      expect(described_class.normalize_e164("555-123-4567")).to eq("+15551234567")
      expect(described_class.normalize_e164("(555) 123-4567")).to eq("+15551234567")
      expect(described_class.normalize_e164("5551234567")).to eq("+15551234567")
    end

    it "preserves the leading 1 if already present (11-digit US format)" do
      expect(described_class.normalize_e164("1-555-123-4567")).to eq("+15551234567")
    end

    it "trims whitespace" do
      expect(described_class.normalize_e164("  +15551234567 ")).to eq("+15551234567")
    end
  end

  describe ".send_sms" do
    context "without credentials" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("QUO_API_KEY").and_return(nil)
        allow(ENV).to receive(:[]).with("QUO_FROM").and_return(nil)
      end

      it "stubs the send and returns a placeholder id" do
        id = described_class.send_sms(to: "+15551234567", body: "hi")
        expect(id).to match(/\Astub-sms-/)
      end
    end
  end
end

require "rails_helper"

RSpec.describe SmsBodyBuilder do
  def notif_double(event:, assigned_to: nil)
    request_type = double("RequestType", name: "Wash")
    boat = double("Boat", name: "Sea Star")
    request = double("Request", boat: boat, request_type: request_type, assigned_to: assigned_to)
    double("Notification", event: event, request: request)
  end

  describe ".for request_completed" do
    it "names who completed the request and includes a Venmo tip link" do
      helper = build(:user, :helper, name: "Hannah Helper", venmo_handle: "@hannah")
      body = described_class.for(notif_double(event: "request_completed", assigned_to: helper))

      expect(body).to include("Wash for Sea Star is complete")
      expect(body).to include("Completed by Hannah Helper")
      expect(body).to include("Send Hannah Helper a tip: https://venmo.com/hannah?txn=pay&note=Tip%20for%20Wash")
      expect(body).to end_with("Reply STOP to opt out.")
    end

    it "names the helper but omits the tip link when they have no Venmo handle" do
      helper = build(:user, :helper, name: "Hannah Helper")
      body = described_class.for(notif_double(event: "request_completed", assigned_to: helper))

      expect(body).to include("Completed by Hannah Helper")
      expect(body).not_to include("venmo.com")
      expect(body).not_to include("Send")
    end

    it "falls back to a plain completion message when nobody is assigned" do
      body = described_class.for(notif_double(event: "request_completed", assigned_to: nil))

      expect(body).to eq("Marina: Wash for Sea Star is complete. Reply STOP to opt out.")
    end
  end
end

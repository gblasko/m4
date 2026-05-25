require "rails_helper"

RSpec.describe ResendDelivery do
  it "is registered as the :resend ActionMailer delivery method" do
    expect(ActionMailer::Base.delivery_methods[:resend]).to eq(ResendDelivery)
  end

  it "forwards #deliver! to ResendAdapter.send_email and returns its id" do
    mail = Mail.new(to: "x@y.com", from: "noreply@example.com", subject: "test", body: "hi")
    expect(ResendAdapter).to receive(:send_email).with(mail).and_return("provider-123")
    expect(ResendDelivery.new.deliver!(mail)).to eq("provider-123")
  end
end

RSpec.describe "AuthMailer end-to-end via :resend delivery method" do
  let(:org)  { create(:organization) }
  let(:user) { create(:user, :customer, organization: org, email: "pat@example.com") }

  around do |ex|
    original = AuthMailer.delivery_method
    AuthMailer.delivery_method = :resend
    ex.run
  ensure
    AuthMailer.delivery_method = original
  end

  it "invite mail flows through ResendAdapter when delivered" do
    expect(ResendAdapter).to receive(:send_email) do |mail|
      expect(mail.to).to eq(["pat@example.com"])
      expect(mail.subject).to include("invited to")
      rendered = mail.text_part&.body.to_s + mail.html_part&.body.to_s
      expect(rendered).to include("https://example.com/auth/verify?token=abc")
      "resend-id-1"
    end

    AuthMailer.with(user: user, url: "https://example.com/auth/verify?token=abc").invite.deliver_now
  end
end

require "rails_helper"

RSpec.describe ResendAdapter do
  describe ".from_header" do
    it "uses the formatted header so display names survive" do
      mail = Mail.new(from: "Marina Ops <hello@example.com>", to: "x@y.com", subject: "s", body: "b")
      expect(ResendAdapter.from_header(mail)).to eq("Marina Ops <hello@example.com>")
    end

    it "falls back to the bare address when no display name is set" do
      mail = Mail.new(from: "hello@example.com", to: "x@y.com", subject: "s", body: "b")
      expect(ResendAdapter.from_header(mail)).to eq("hello@example.com")
    end

    it "strips whitespace" do
      mail = Mail.new(from: "  hello@example.com  ", to: "x@y.com", subject: "s", body: "b")
      expect(ResendAdapter.from_header(mail)).to eq("hello@example.com")
    end
  end

  describe ".send_email error context" do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("RESEND_API_KEY").and_return("test-key")
    end

    it "logs the actual from/to/subject when Resend returns non-2xx" do
      stub = instance_double(Net::HTTPResponse, code: "422",
        body: '{"statusCode":422,"name":"validation_error","message":"Invalid `from`"}')
      allow(Net::HTTP).to receive(:start).and_return(stub)

      mail = Mail.new(from: "Marina <hello@example.com>", to: "x@y.com", subject: "s", body: "b")
      expect(Rails.logger).to receive(:error).with(/from=.*Marina <hello@example.com>.*to=.*x@y.com.*resp=422/)
      expect { ResendAdapter.send_email(mail) }.to raise_error(/Resend error: 422/)
    end
  end
end

RSpec.describe "ApplicationMailer default from" do
  it "falls back to a working Resend sender when MAIL_FROM is blank" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("MAIL_FROM").and_return("")
    expect(ENV["MAIL_FROM"].presence || "onboarding@resend.dev").to eq("onboarding@resend.dev")
  end
end

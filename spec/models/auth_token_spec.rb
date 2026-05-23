require "rails_helper"

RSpec.describe AuthToken, type: :model do
  let(:user) { create(:user) }

  it "generates and consumes a magic-link token once" do
    raw, _ = AuthToken.generate!(user: user, channel: "email")
    expect(AuthToken.consume_by_token(raw)).to eq(user)
    expect(AuthToken.consume_by_token(raw)).to be_nil # single-use
  end

  it "consumes an SMS code only when matching" do
    _raw, code = AuthToken.generate!(user: user, channel: "sms")
    expect(AuthToken.consume_by_code(user: user, code: "wrong")).to be_nil
    expect(AuthToken.consume_by_code(user: user, code: code)).to eq(user)
  end

  it "rejects expired tokens" do
    raw, _ = AuthToken.generate!(user: user, channel: "email")
    AuthToken.last.update_columns(expires_at: 1.minute.ago)
    expect(AuthToken.consume_by_token(raw)).to be_nil
  end
end

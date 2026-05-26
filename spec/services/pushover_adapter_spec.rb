require "rails_helper"

RSpec.describe PushoverAdapter do
  describe "without an app key" do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("PUSHOVER_APP_API_KEY").and_return(nil)
    end

    it ".send_message stubs and returns a placeholder id" do
      id = described_class.send_message(group_key: "G", message: "hi")
      expect(id).to match(/\Astub-push-/)
    end

    it ".add_user_to_group stubs and returns a placeholder id" do
      expect(described_class.add_user_to_group(group_key: "G", user_key: "U")).to match(/\Astub-push-/)
    end

    it ".remove_user_from_group stubs and returns a placeholder id" do
      expect(described_class.remove_user_from_group(group_key: "G", user_key: "U")).to match(/\Astub-push-/)
    end

    it ".validate_user is permissive (true) in stub mode" do
      expect(described_class.validate_user(user_key: "anything")).to be true
    end
  end

  describe "with an app key" do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("PUSHOVER_APP_API_KEY").and_return("test-token")
    end

    def stub_response(code:, body:)
      Struct.new(:code, :body).new(code.to_s, body)
    end

    it ".send_message posts to messages.json and returns the request id" do
      resp = stub_response(code: 200, body: { status: 1, request: "abc-123" }.to_json)
      expect(Net::HTTP).to receive(:start).and_return(resp)

      expect(described_class.send_message(group_key: "G", message: "hello", title: "T", url: "https://x"))
        .to eq("abc-123")
    end

    it ".send_message raises on status:0 from Pushover" do
      resp = stub_response(code: 200, body: { status: 0, errors: ["application token is invalid"] }.to_json)
      allow(Net::HTTP).to receive(:start).and_return(resp)

      expect {
        described_class.send_message(group_key: "G", message: "x")
      }.to raise_error(PushoverAdapter::Error, /application token/)
    end

    it ".send_message treats an empty delivery group as a successful no-op" do
      resp = stub_response(code: 400, body: { status: 0, user: "invalid",
                                              errors: ["group has no users or active devices in it"] }.to_json)
      allow(Net::HTTP).to receive(:start).and_return(resp)

      expect {
        described_class.send_message(group_key: "G", message: "x")
      }.not_to raise_error
    end

    it ".add_user_to_group treats 'already exists' as success" do
      resp = stub_response(code: 200, body: { status: 0, errors: ["user already exists in group"] }.to_json)
      expect(Net::HTTP).to receive(:start).and_return(resp)

      expect(described_class.add_user_to_group(group_key: "G", user_key: "U")).to be true
    end

    it ".remove_user_from_group treats 'not found' as success" do
      resp = stub_response(code: 200, body: { status: 0, errors: ["user is not found in group"] }.to_json)
      expect(Net::HTTP).to receive(:start).and_return(resp)

      expect(described_class.remove_user_from_group(group_key: "G", user_key: "U")).to be true
    end

    it ".validate_user returns true on status:1" do
      resp = stub_response(code: 200, body: { status: 1 }.to_json)
      allow(Net::HTTP).to receive(:start).and_return(resp)
      expect(described_class.validate_user(user_key: "U")).to be true
    end

    it ".validate_user returns false on status:0" do
      resp = stub_response(code: 200, body: { status: 0, errors: ["user identifier is not a valid user"] }.to_json)
      allow(Net::HTTP).to receive(:start).and_return(resp)
      expect(described_class.validate_user(user_key: "U")).to be false
    end

    it ".validate_user returns false on a blank key without hitting the network" do
      expect(Net::HTTP).not_to receive(:start)
      expect(described_class.validate_user(user_key: "")).to be false
    end
  end
end

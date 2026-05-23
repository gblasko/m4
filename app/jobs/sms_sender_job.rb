class SmsSenderJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(to:, body:)
    TwilioAdapter.send_sms(to: to, body: body)
  end
end

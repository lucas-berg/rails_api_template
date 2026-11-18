# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SweepMailDeliveriesJob do
  it 'requeues due mail and abandoned leases but not active or terminal deliveries' do
    user = create(:user)
    deliveries = Array.new(5) { MailDelivery.enqueue_devise(user, :password_change) }
    deliveries[1].update!(status: 'sending', locked_at: 6.minutes.ago, lease_token: 'old')
    deliveries[2].update!(status: 'sending', locked_at: Time.current, lease_token: 'current')
    deliveries[3].update!(status: 'sent', encrypted_payload: nil)
    deliveries[4].update!(next_attempt_at: 1.hour.from_now)
    clear_enqueued_jobs

    described_class.perform_now

    expect(enqueued_jobs.pluck(:args)).to contain_exactly([deliveries[0].id], [deliveries[1].id])
  end
end

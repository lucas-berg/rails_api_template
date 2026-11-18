# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SweepNotificationDeliveriesJob do
  it 'recovers persisted security emails that were not queued' do
    user = create(:user)
    notification = Notifications::Publish.call(user:, kind: 'password_changed', event_key: 'password-1')
    delivery = notification.notification_deliveries.find_by!(channel: 'email')
    clear_enqueued_jobs

    expect { described_class.perform_now }.to have_enqueued_job(SendNotificationDeliveryJob).with(delivery.id)
  end
end

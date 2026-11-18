# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Platform::RetryNotification do
  let(:notification) do
    Notifications::Publish.call(user: create(:user), kind: 'password_changed', event_key: SecureRandom.uuid)
  end
  let(:delivery) { notification.notification_deliveries.find_by!(channel: 'email') }

  it 'rejects direct service calls by support without changing the delivery' do
    delivery.update!(status: 'failed', attempts: 8)
    service = described_class.new(actor: create(:admin_user, :support), record: delivery, request_id: 'retry-test')

    expect { service.call(reason: 'SMTP recovered') }.to raise_error(Pundit::NotAuthorizedError)
    expect(delivery.reload).to have_attributes(status: 'failed', attempts: 8)
    expect(AuditEvent.where(action: 'notification_delivery.retried')).to be_empty
  end

  it 'rolls back the retry when its required audit event cannot be persisted' do
    delivery.update!(status: 'failed', attempts: 8)
    service = described_class.new(actor: create(:admin_user), record: delivery, request_id: 'retry-test')
    allow(AuditEvent).to receive(:record!).and_raise(ActiveRecord::RecordInvalid)

    expect { service.call(reason: 'SMTP recovered') }.to raise_error(ActiveRecord::RecordInvalid)
    expect(delivery.reload).to have_attributes(status: 'failed', attempts: 8)
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Notification delivery administration' do
  let(:user) { create(:user) }
  let(:notification) do
    Notifications::Publish.call(user:, kind: 'password_changed', event_key: SecureRandom.uuid)
  end
  let(:delivery) { notification.notification_deliveries.find_by!(channel: 'email') }

  it 'audits retries by a super administrator' do
    delivery.update!(status: 'failed', attempts: 8)
    sign_in create(:admin_user)
    post "/admin/notification_deliveries/#{delivery.id}/retry_delivery", params: { reason: 'SMTP recovered' }
    expect(response).to have_http_status(:found)
    expect(delivery.reload).to have_attributes(status: 'pending', attempts: 0)
    expect(AuditEvent.find_by!(action: 'notification_delivery.retried').reason).to eq('SMTP recovered')
  end

  it 'denies support retry access' do
    delivery.update!(status: 'failed', attempts: 8)
    sign_in create(:admin_user, :support)
    post "/admin/notification_deliveries/#{delivery.id}/retry_delivery", params: { reason: 'Try again' }
    expect(response).to have_http_status(:forbidden)
    expect(delivery.reload.status).to eq('failed')
  end

  it 'reports a state conflict when a retry is no longer applicable' do
    sign_in create(:admin_user)
    post "/admin/notification_deliveries/#{delivery.id}/retry_delivery", params: { reason: 'Already queued' }
    expect(response).to have_http_status(:conflict)
    expect(AuditEvent.where(action: 'notification_delivery.retried')).to be_empty
  end
end

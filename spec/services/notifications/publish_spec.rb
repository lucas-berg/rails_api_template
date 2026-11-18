# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notifications::Publish do
  let(:user) { create(:user) }
  let(:team) { create(:team) }

  before { create(:member, user:, team:) }

  def publish(event_key: 'member-role-1')
    described_class.call(user:, team:, kind: 'member_role_changed', event_key:)
  end

  it 'creates one visible in-app notification and disables optional email by default' do
    notification = publish
    expect(notification.visible_at).to be_present
    expect(notification.notification_deliveries.pluck(:channel, :status))
      .to contain_exactly(%w[in_app sent], %w[email skipped])
    expect(notification.presentation.fetch('body')).to eq('Your permissions in this team have changed.')
  end

  it 'deduplicates repeat publication by recipient, event, and channel' do
    first = publish
    expect { expect(publish.id).to eq(first.id) }.not_to change(NotificationDelivery, :count)
    expect(Notification.count).to eq(1)
    expect(NotificationDelivery.count).to eq(2)
  end

  it 'rejects reusing an event key for a different kind' do
    publish
    expect {
      described_class.call(user:, team:, kind: 'ownership_transferred', event_key: 'member-role-1')
    }.to raise_error(ArgumentError, /already been used/)
  end

  it 'allows the same business event to notify separate recipients' do
    other = create(:user)
    create(:member, user: other, team:)
    publish
    expect {
      described_class.call(user: other, team:, kind: 'member_role_changed', event_key: 'member-role-1')
    }.to change(Notification, :count).by(1)
  end

  it 'respects activity preferences without allowing security alerts to be disabled' do
    NotificationPreference.create!(user:, activity_in_app: false, activity_email: false)
    activity = publish
    expect(activity.visible_at).to be_nil
    expect(activity.notification_deliveries.pluck(:status)).to eq(%w[skipped skipped])

    security = described_class.call(user:, kind: 'password_changed', event_key: 'password-version-1')
    expect(security.visible_at).to be_present
    expect(security.notification_deliveries.find_by!(channel: 'email').status).to eq('pending')
  end

  it 'does not deliver activity to someone who is no longer a member' do
    team.members.find_by!(user:).update!(status: 'removed')
    notification = publish
    expect(notification.visible_at).to be_nil
    expect(notification.notification_deliveries.pluck(:status)).to eq(%w[skipped skipped])
  end

  it 'rolls notifications and delivery intent back with the business transaction' do
    Notification.transaction do
      publish
      raise ActiveRecord::Rollback
    end
    expect(Notification.count).to eq(0)
    expect(NotificationDelivery.count).to eq(0)
  end

  it 'requires team activity and personal security to use the correct scope' do
    expect {
      described_class.call(user:, team:, kind: 'password_changed', event_key: 'bad-scope')
    }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'does not accept arbitrary content or token payloads' do
    expect {
      described_class.call(user:, kind: 'password_changed', event_key: 'safe-event', payload: { token: 'secret' })
    }.to raise_error(ArgumentError, /unknown keyword/)
  end
end

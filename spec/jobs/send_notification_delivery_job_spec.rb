# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SendNotificationDeliveryJob do
  let(:user) { create(:user) }
  let(:team) { create(:team) }
  let!(:member) { create(:member, user:, team:) }

  before do
    NotificationPreference.create!(user:, activity_email: true)
    ActionMailer::Base.deliveries.clear
    clear_enqueued_jobs
  end

  def activity_delivery
    notification = Notifications::Publish.call(user:, team:, kind: 'member_role_changed', event_key: 'role-1')
    notification.notification_deliveries.find_by!(channel: 'email')
  end

  it 'sends optional activity mail once for repeated jobs' do
    delivery = activity_delivery
    expect { described_class.perform_now(delivery.id) }.to change(ActionMailer::Base.deliveries, :count).by(1)
    expect(ActionMailer::Base.deliveries.last.to).to eq([user.email])
    expect(delivery.reload.status).to eq('sent')
    expect { described_class.perform_now(delivery.id) }.not_to change(ActionMailer::Base.deliveries, :count)
    expect(Current.user).to be_nil
    expect(Current.team).to be_nil
  end

  it 'rechecks membership before sending a queued team message' do
    delivery = activity_delivery
    member.update!(status: 'removed')
    expect { described_class.perform_now(delivery.id) }.not_to change(ActionMailer::Base.deliveries, :count)
    expect(delivery.reload.status).to eq('skipped')
  end

  it 'rechecks team suspension before sending' do
    delivery = activity_delivery
    team.update!(status: 'suspended')
    expect { described_class.perform_now(delivery.id) }.not_to change(ActionMailer::Base.deliveries, :count)
    expect(delivery.reload.status).to eq('skipped')
  end

  it 'rechecks preferences after the event was published' do
    delivery = activity_delivery
    NotificationPreference.find_by!(user:).update!(activity_email: false)
    expect { described_class.perform_now(delivery.id) }.not_to change(ActionMailer::Base.deliveries, :count)
    expect(delivery.reload.status).to eq('skipped')
  end

  it 'uses the current personal language when sending an already queued notification' do
    delivery = activity_delivery
    user.update!(preferences: { 'locale' => 'zh-CN' })
    described_class.perform_now(delivery.id)

    message = ActionMailer::Base.deliveries.last
    expect(message.subject).to eq('您的团队角色已更改')
    expect(message.body.decoded).to include('您在此团队中的权限已更改。')
  end

  it 'sends compulsory security alerts even for a suspended user' do
    user.suspend!
    NotificationPreference.find_by!(user:).update!(activity_email: false)
    notification = Notifications::Publish.call(user:, kind: 'account_suspended', event_key: 'suspension-1')
    delivery = notification.notification_deliveries.find_by!(channel: 'email')
    expect { described_class.perform_now(delivery.id) }.to change(ActionMailer::Base.deliveries, :count).by(1)
    expect(delivery.reload.status).to eq('sent')
  end

  it 'records only the error class and retries after transport failure' do
    delivery = activity_delivery
    message = instance_double(ActionMailer::MessageDelivery)
    allow(NotificationMailer).to receive(:notice).and_return(message)
    allow(message).to receive(:deliver_now).and_raise(IOError, 'private SMTP credentials')
    described_class.perform_now(delivery.id)

    expect(delivery.reload).to have_attributes(status: 'pending', attempts: 1, last_error: 'IOError')
    expect(delivery.next_attempt_at).to be > Time.current
    expect(Current.user).to be_nil
  end

  it 'does not let a worker with an old lease overwrite a recovered delivery' do
    delivery = activity_delivery
    old_lease = delivery.claim!
    travel 6.minutes do
      current_lease = delivery.claim!
      expect(current_lease).not_to eq(old_lease)
      delivery.finish!(old_lease)
      expect(delivery.reload.status).to eq('sending')
      delivery.finish!(current_lease)
      expect(delivery.reload.status).to eq('sent')
    end
  end

  it 'stops automatically retrying after the attempt limit' do
    delivery = activity_delivery
    delivery.update!(attempts: NotificationDelivery::MAX_ATTEMPTS)
    expect { described_class.perform_now(delivery.id) }.not_to change(ActionMailer::Base.deliveries, :count)
    expect(delivery.reload.status).to eq('failed')
    delivery.retry_delivery!
    expect(delivery.reload).to have_attributes(status: 'pending', attempts: 0)
  end

  it 'ignores rows removed by retention cleanup' do
    expect { described_class.perform_now(-1) }.not_to raise_error
  end
end

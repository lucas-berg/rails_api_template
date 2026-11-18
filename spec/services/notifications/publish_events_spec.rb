# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notifications::Publish do
  let(:owner) { create(:user) }
  let(:team) { Teams::Create.call(actor: owner, attributes: { name: 'Events team' }) }

  it 'publishes password changes and suspension transitions as mandatory security events' do
    owner.update!(password: 'A-changed-secure-password!')
    owner.suspend!
    owner.restore!

    expect(Notification.where(user: owner).pluck(:kind))
      .to contain_exactly('password_changed', 'account_suspended', 'account_restored')
    expect(NotificationDelivery.where(channel: 'email').pluck(:status)).to eq(%w[pending pending pending])
  end

  it 'does not publish a suspension twice when the status does not change' do
    owner.suspend!
    expect { owner.suspend! }.not_to change(Notification, :count)
  end

  it 'rolls security notifications and credential changes back together' do
    original_password = owner.encrypted_password
    User.transaction do
      owner.update!(password: 'A-rolled-back-password!')
      raise ActiveRecord::Rollback
    end

    expect(Notification.count).to eq(0)
    expect(NotificationDelivery.count).to eq(0)
    expect(owner.reload.encrypted_password).to eq(original_password)
  end

  it 'rolls the password change back when notification persistence fails' do
    original_password = owner.encrypted_password
    allow(described_class).to receive(:call).and_raise(ActiveRecord::RecordInvalid)
    expect { owner.update!(password: 'An-uncommitted-password!') }.to raise_error(ActiveRecord::RecordInvalid)

    expect(owner.reload.encrypted_password).to eq(original_password)
    expect(owner.credentials_version).to eq(0)
  end

  it 'publishes acceptance once when the same invitation is accepted twice' do
    invited = create(:user)
    invitation = Invitations::Create.new(actor: owner, team:).call(email: invited.email)
    token = MailDelivery.where(kind: 'invitation').last.payload.fetch('token')
    Invitations::Accept.call(actor: invited, token:)
    expect { Invitations::Accept.call(actor: invited, token:) }.not_to change(Notification, :count)

    notification = Notification.find_by!(user: invited, kind: 'invitation_accepted')
    expect(notification.event_key).to eq("invitation:#{invitation.id}:accepted")
    expect(notification.team_id).to eq(team.id)
  end

  it 'rolls invitation acceptance back if the notification cannot be persisted' do
    invited = create(:user)
    invitation = Invitations::Create.new(actor: owner, team:).call(email: invited.email)
    token = MailDelivery.where(kind: 'invitation').last.payload.fetch('token')
    allow(described_class).to receive(:call).and_raise(ActiveRecord::RecordInvalid)
    expect { Invitations::Accept.call(actor: invited, token:) }.to raise_error(ActiveRecord::RecordInvalid)

    expect(invitation.reload.accepted_at).to be_nil
    expect(Member.where(team:, user: invited)).to be_empty
    expect(AuditEvent.where(action: 'invitation.accepted')).to be_empty
  end

  it 'notifies a changed member without generating a notification for a no-op role update' do
    member = create(:member, team:)
    Members::ChangeRole.new(actor: owner, team:).call(member.id, 'viewer')
    expect(Notification.find_by!(user: member.user).kind).to eq('member_role_changed')

    expect {
      Members::ChangeRole.new(actor: owner, team:).call(member.id, 'viewer')
    }.not_to change(Notification, :count)
  end

  it 'notifies both the former and new owner atomically' do
    member = create(:member, team:)
    Members::TransferOwnership.new(actor: owner, team:).call(member.id)

    notifications = Notification.where(kind: 'ownership_transferred')
    expect(notifications.pluck(:user_id)).to contain_exactly(owner.id, member.user_id)
    expect(notifications.pluck(:event_key).uniq.size).to eq(1)
  end
end

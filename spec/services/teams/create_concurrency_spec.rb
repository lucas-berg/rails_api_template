# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Teams::Create do
  self.use_transactional_tests = false

  let!(:owner) { create(:user) }
  let!(:recipient) { create(:user) }
  let!(:other) { create(:user) }
  let!(:team) { described_class.call(actor: owner, attributes: { name: 'Concurrent team' }) }

  after do
    user_ids = [owner, recipient, other].compact.map(&:id)
    team_id = team&.id
    notifications = Notification.where(user_id: user_ids)
    NotificationDelivery.where(notification_id: notifications.select(:id)).delete_all
    notifications.delete_all
    NotificationPreference.where(user_id: user_ids).delete_all
    MailDelivery.where(user_id: user_ids).delete_all
    AuditEvent.where(team_id: team_id).delete_all
    Invitation.where(team_id: team_id).delete_all
    Member.where(team_id: team_id).delete_all
    Team.where(id: team_id).delete_all
    AuthSession.where(user_id: user_ids).delete_all
    User.where(id: user_ids).delete_all
  end

  def race(*arguments, &operation)
    ready = Queue.new
    gate = Queue.new
    threads = arguments.map { |argument| race_worker(argument, ready, gate, &operation) }
    arguments.size.times { ready.pop }
    arguments.size.times { gate << true }
    threads.map(&:value)
  end

  def race_worker(argument, ready, gate)
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        ready << true
        gate.pop
        yield(argument)
      rescue StandardError => error
        error
      end
    end
  end

  it 'serializes duplicate invitation acceptance across independent database connections' do
    invitation = Invitations::Create.new(actor: owner, team: team).call(email: recipient.email)
    token = MailDelivery.where(kind: 'invitation', team_id: team.id).last.payload.fetch('token')
    results = race(recipient.id, recipient.id) do |user_id|
      Invitations::Accept.call(actor: User.find(user_id), token:)
    end

    expect(results).to all(be_a(Member))
    expect(results.map(&:id).uniq.size).to eq(1)
    expect(Member.where(team_id: team.id, user_id: recipient.id).count).to eq(1)
    expect(invitation.reload.accepted_at).to be_present
    expect(AuditEvent.where(team_id: team.id, action: 'invitation.accepted').count).to eq(1)
    expect(Notification.where(user_id: recipient.id, kind: 'invitation_accepted').count).to eq(1)
  end

  it 'permits only one simultaneous ownership transfer from the same owner' do
    first = create(:member, team: team, user: recipient)
    second = create(:member, team: team, user: other)
    results = race(first.id, second.id) do |member_id|
      Members::TransferOwnership.new(actor: User.find(owner.id), team: Team.find(team.id)).call(member_id)
    end

    expect(results.count { |result| result.is_a?(Member) }).to eq(1)
    expect(results.count { |result| result.is_a?(Authorization::Forbidden) }).to eq(1)
    expect(team.active_members.owner.count).to eq(1)
    expect(team.active_members.find_by!(user: owner)).to be_admin
    expect(AuditEvent.where(team_id: team.id, action: 'team.ownership_transferred').count).to eq(1)
  end
end

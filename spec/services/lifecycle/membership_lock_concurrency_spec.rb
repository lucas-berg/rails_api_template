# frozen_string_literal: true

require 'rails_helper'
require 'timeout'

RSpec.describe Lifecycle::MembershipLock do
  self.use_transactional_tests = false

  let!(:owner) { create(:user) }
  let!(:recipient) { create(:user) }

  after do
    user_ids = [owner.id, recipient.id]
    team_ids = Member.where(user_id: user_ids).distinct.pluck(:team_id)
    notifications = Notification.where(user_id: user_ids)
    NotificationDelivery.where(notification_id: notifications.select(:id)).delete_all
    notifications.delete_all
    NotificationPreference.where(user_id: user_ids).delete_all
    MailDelivery.where(user_id: user_ids).delete_all
    AuditEvent.where(team_id: team_ids).or(AuditEvent.where(actor_type: 'User', actor_id: user_ids)).delete_all
    DeletionRequest.where(requested_by_id: user_ids).delete_all
    Invitation.where(team_id: team_ids).delete_all
    Member.where(team_id: team_ids).delete_all
    Team.where(id: team_ids).delete_all
    AuthSession.where(user_id: user_ids).delete_all
    User.where(id: user_ids).delete_all
  end

  # The barrier must collect every ready signal before releasing any worker.
  # :reek:DuplicateMethodCall
  def race(&)
    ready = Queue.new
    gate = Queue.new
    threads = %i[acquire_ownership request_deletion].map { |action| worker(action, ready, gate, &) }
    2.times { ready.pop }
    2.times { gate << true }
    Timeout.timeout(10) { threads.map(&:value) }
  ensure
    terminate_workers(threads)
  end

  # Ensure database connections are released even when a concurrency assertion times out.
  # :reek:FeatureEnvy
  def terminate_workers(threads)
    Array(threads).each do |thread|
      thread.kill if thread.alive?
      thread.join
    end
  end

  def worker(action, ready, gate)
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        ready << true
        gate.pop
        yield(action)
      rescue StandardError => error
        error
      end
    end
  end

  it 'serializes new team ownership against an account deletion request' do
    recipient_id = recipient.id
    password = recipient.password
    results = race do |action|
      actor = User.find(recipient_id)
      if action == :acquire_ownership
        Teams::Create.call(actor:, attributes: { name: 'Concurrent new team' })
      else
        Deletions::Request.call(actor:, subject: actor, password:)
      end
    end

    expect(results.count { |result| result.is_a?(Team) || result.is_a?(DeletionRequest) }).to eq(1)
    expect(results.count { |result| result.is_a?(Collaboration::Conflict) }).to eq(1)
    expect(DeletionRequest.exists?(subject: recipient))
      .not_to eq(Member.exists?(user: recipient, role: 'owner', status: 'active'))
  end

  it 'serializes incoming ownership transfer against the recipient deletion request' do
    team = Teams::Create.call(actor: owner, attributes: { name: 'Concurrent transfer team' })
    member = create(:member, user: recipient, team:)
    recipient_id = recipient.id
    password = recipient.password
    results = race do |action|
      if action == :acquire_ownership
        Members::TransferOwnership.new(actor: User.find(owner.id), team: Team.find(team.id)).call(member.id)
      else
        actor = User.find(recipient_id)
        Deletions::Request.call(actor:, subject: actor, password:)
      end
    end

    expect(results.count { |result| result.is_a?(Member) || result.is_a?(DeletionRequest) }).to eq(1)
    expect(results.count { |result| result.is_a?(Collaboration::Conflict) }).to eq(1)
    expect(DeletionRequest.exists?(subject: recipient)).not_to eq(member.reload.owner?)
    expect(team.active_members.owner.count).to eq(1)
  end
end

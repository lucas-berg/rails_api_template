# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lifecycle::ReplayDeletions do
  let(:user) { create(:user) }
  let(:team) { Teams::Create.call(actor: user, attributes: { name: 'Restored team' }) }
  let(:ledger_directory) { Dir.mktmpdir('deletion-replay-spec') }

  before { allow(Lifecycle::DeletionLedger).to receive(:directory).and_return(Pathname.new(ledger_directory)) }
  after { FileUtils.remove_entry(ledger_directory) }

  it 'reapplies the independent deletion ledger to restored team records' do
    deletion = Deletions::Request.call(actor: user, subject: team, password: user.password)
    deletion.update!(scheduled_at: 1.minute.ago)
    ProcessDeletionJob.perform_now(deletion.id)
    expect(deletion.reload.status).to eq('completed')

    # Simulate the restored database state without rolling back the independent ledger files.
    # A restore bypasses callbacks just as SQL backup restoration does.
    # rubocop:disable-next Rails/SkipsModelValidations
    team.update_columns(name: 'Restored team', deleted_at: nil, status: 'active')
    create(:member, :owner, user: user, team: team)
    described_class.call
    expect(team.reload.status).to eq('deleted')
    expect(team.members).to be_empty
    expect(DeletionTombstone.where(request_uuid: deletion.uuid).count).to eq(1)
  end

  it 'replays deleted teams before their former owner even when ledger filenames are in the opposite order' do
    team_deletion = Deletions::Request.call(actor: user, subject: team, password: user.password)
    team_deletion.update!(scheduled_at: 1.minute.ago)
    ProcessDeletionJob.perform_now(team_deletion.id)
    user_deletion = Deletions::Request.call(actor: user, subject: user, password: user.password)
    user_deletion.update!(scheduled_at: 1.minute.ago)
    ProcessDeletionJob.perform_now(user_deletion.id)
    entries = Lifecycle::DeletionLedger.entries.sort_by { |entry| entry['subject_type'] == 'User' ? 0 : 1 }
    allow(Lifecycle::DeletionLedger).to receive(:entries).and_return(entries)
    # Each entry is an independent, deliberately sequential recovery transaction and job.
    allow(described_class).to receive(:replay).and_wrap_original do |method, *arguments|
      Prosopite.finish
      Prosopite.scan
      method.call(*arguments)
      Prosopite.finish
      Prosopite.scan
    end
    # Simulate restoration before either deletion completed.
    # rubocop:disable-next Rails/SkipsModelValidations
    team.update_columns(status: 'active', deleted_at: nil)
    # rubocop:disable-next Rails/SkipsModelValidations
    user.update_columns(status: 'active', deleted_at: nil)
    create(:member, :owner, user: user, team: team)

    described_class.call
    expect(team.reload.status).to eq('deleted')
    expect(user.reload).to be_suspended
    expect(user.deleted_at).to be_present
  end

  it 'does not apply a ledger entry to another object that reused the database ID' do
    entry = { 'version' => 1, 'request_uuid' => SecureRandom.uuid, 'subject_type' => 'Team', 'subject_id' => team.id,
              'fingerprint' => 'wrong', 'deleted_at' => Time.current.iso8601 }
    Lifecycle::DeletionLedger.write!(entry)
    expect { described_class.call }.to raise_error(ArgumentError, /fingerprint/)
    expect(team.reload.status).to eq('active')
  end

  it 'keeps a restored deleted account suspended when restored ownership needs manual repair' do
    deletion = Deletions::Request.call(actor: user, subject: user, password: user.password)
    deletion.update!(scheduled_at: 1.minute.ago)
    ProcessDeletionJob.perform_now(deletion.id)
    expect(deletion.reload.status).to eq('completed')
    # rubocop:disable-next Rails/SkipsModelValidations
    user.update_columns(status: 'active', deleted_at: nil)
    restored_team = create(:team)
    create(:member, :owner, user: user, team: restored_team)

    expect { described_class.call }.to raise_error(RuntimeError, /replay failed/)
    expect(user.reload).to be_suspended
    expect(restored_team.active_members.owner.count).to eq(1)
  end
end

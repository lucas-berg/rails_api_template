# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProcessDeletionJob do
  let(:user) { create(:user) }
  let(:team) { Teams::Create.call(actor: user, attributes: { name: 'Deletion fixture' }) }
  let(:ledger_directory) { Dir.mktmpdir('deletion-ledger-spec') }

  before { allow(Lifecycle::DeletionLedger).to receive(:directory).and_return(Pathname.new(ledger_directory)) }
  after { FileUtils.remove_entry(ledger_directory) }

  def due_request(subject)
    request = Deletions::Request.call(actor: user, subject: subject, password: user.password)
    request.update!(scheduled_at: 1.minute.ago)
    request
  end

  it 'anonymizes the team and records a durable external ledger before removing members' do
    request = due_request(team)
    described_class.perform_now(request.id)
    expect(request.reload.status).to eq('completed')
    expect(team.reload.status).to eq('deleted')
    expect(team.name).to eq('Deleted team')
    expect(team.members).to be_empty
    expect(DeletionTombstone.find_by!(request_uuid: request.uuid).subject_id).to eq(team.id)
    expect(Lifecycle::DeletionLedger.entries.first['subject_id']).to eq(team.id)
    expect { described_class.perform_now(request.id) }.not_to change(DeletionTombstone, :count)
  end

  it 'revokes sessions and anonymizes user data while sending completion to the captured original address' do
    original_email = user.email
    auth_headers(user)
    request = due_request(user)
    described_class.perform_now(request.id)
    expect(request.reload.status).to eq('completed')
    expect(user.reload).to be_suspended
    expect(user.email).to eq("deleted-#{user.id}@deleted.invalid")
    expect(user.auth_sessions).to be_empty
    SendDeletionNoticeJob.perform_now(request.id)
    expect(ActionMailer::Base.deliveries.last.to).to eq([original_email])
    expect(request.reload.encrypted_recipient).to be_nil
  end

  it 'clears team invitations, notifications and mail while retaining the completion audit' do
    invitation = Invitations::Create.new(actor: user, team: team).call(email: 'remove@example.com')
    request = due_request(team)

    described_class.perform_now(request.id)

    expect(request.reload).to have_attributes(status: 'completed', stage: 'completed')
    expect(Invitation.exists?(invitation.id)).to be(false)
    expect(Notification.where(team: team)).to be_empty
    expect(MailDelivery.where(team_id: team.id)).to be_empty
    expect(team.audit_events.where(action: 'deletion.completed')).to exist
  end

  it 'performs no irreversible cleanup if the independent ledger cannot be written' do
    request = due_request(team)
    allow(Lifecycle::DeletionLedger).to receive(:write!).and_raise(IOError)
    described_class.perform_now(request.id)
    expect(request.reload.status).to eq('failed')
    expect(team.reload.status).to eq('deleting')
    expect(request.stage).to eq('ledger')
    expect(team.members).not_to be_empty
    expect(team.deleted_at).to be_nil
    expect {
      Deletions::Cancel.call(actor: user, deletion: request, password: user.password)
    }.to raise_error(Collaboration::Conflict, /no longer/)
  end

  it 'rechecks last-owner protection at execution instead of trusting the request-time check' do
    request = due_request(user)
    unsafe_team = create(:team)
    create(:member, :owner, team: unsafe_team, user: user)
    described_class.perform_now(request.id)
    expect(request.reload.status).to eq('failed')
    expect(user.reload).to be_active_for_authentication
    expect(unsafe_team.active_members.owner.count).to eq(1)
  end

  it 'resumes after a cleanup failure without duplicating ledger entries' do
    request = due_request(team)
    cleanup = Deletions::Cleanup.new(request)
    allow(Deletions::Cleanup).to receive(:new).and_return(cleanup)
    allow(cleanup).to receive(:call).and_raise(IOError)
    described_class.perform_now(request.id)
    expect(request.reload.status).to eq('failed')
    expect(team.reload.status).to eq('deleting')
    allow(cleanup).to receive(:call).and_call_original
    described_class.perform_now(request.id)
    expect(request.reload.status).to eq('completed')
    expect(DeletionTombstone.where(request_uuid: request.uuid).count).to eq(1)
    expect(Lifecycle::DeletionLedger.entries.size).to eq(1)
  end

  it 'does not execute canceled or not-yet-due requests' do
    request = Deletions::Request.call(actor: user, subject: team, password: user.password)
    described_class.perform_now(request.id)
    expect(request.reload.status).to eq('pending')
    Deletions::Cancel.call(actor: user, deletion: request, password: user.password)
    request.update!(scheduled_at: 1.minute.ago)
    described_class.perform_now(request.id)
    expect(team.reload.status).to eq('active')
    expect(request.reload.status).to eq('canceled')
  end
end

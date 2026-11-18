# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SweepDeletionsJob do
  let(:user) { create(:user) }

  it 'clears expired audit data and undelivered completion addresses according to retention rules' do
    old_audit = AuditEvent.record!(actor: user, action: 'profile.updated', target: user)
    old_audit.update!(occurred_at: 366.days.ago)
    recent_audit = AuditEvent.record!(actor: user, action: 'profile.updated', target: user)
    deletion = DeletionRequest.create!(subject: user, requested_by: user, status: 'completed', stage: 'completed',
                                       scheduled_at: 40.days.ago, completed_at: 31.days.ago, recipient: user.email)
    described_class.perform_now
    expect(AuditEvent.exists?(old_audit.id)).to be(false)
    expect(AuditEvent.exists?(recent_audit.id)).to be(true)
    expect(deletion.reload.encrypted_recipient).to be_nil
  end

  it 'marks crashed workers exhausted rather than automatically exceeding the retry budget' do
    deletion = DeletionRequest.create!(subject: user, requested_by: user, status: 'processing', stage: 'ledger',
                                       scheduled_at: 1.day.ago, processing_started_at: 11.minutes.ago, attempts: 8)
    clear_enqueued_jobs
    described_class.perform_now
    expect(deletion.reload.status).to eq('failed')
    expect(deletion.failure_code).to eq('attempts_exhausted')
    expect(ProcessDeletionJob).not_to have_been_enqueued
  end
end

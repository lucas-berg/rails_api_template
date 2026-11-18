# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CleanupDocumentsJob do
  it 'expires abandoned uploads and schedules safe cleanup' do
    document = create(:document, upload_expires_at: 1.minute.ago)
    expect { described_class.perform_now }.to have_enqueued_job(PurgeDocumentJob).with(document.id)
    expect(document.reload).to have_attributes(status: 'rejected', failure_code: 'upload_expired')
  end

  it 'recovers lost verification jobs and interrupted purges' do
    verifying = create(:document, status: 'processing', verification_requested_at: 11.minutes.ago)
    deleting = create(:document, status: 'deleting', purge_requested_at: 11.minutes.ago)
    clear_enqueued_jobs
    described_class.perform_now
    expect(enqueued_jobs).to include(hash_including(job: VerifyDocumentJob, args: [verifying.id]))
    expect(enqueued_jobs).to include(hash_including(job: PurgeDocumentJob, args: [deleting.id]))
  end
end

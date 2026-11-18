# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PurgeDocumentJob do
  it 'deletes bytes and metadata idempotently' do
    document = create(:document, status: 'deleting')
    blob = document.file.blob
    key = blob.key
    described_class.perform_now(document.id)
    expect(document.reload.status).to eq('deleted')
    expect(document.purged_at).to be_present
    expect(blob.service.exist?(key)).to be(false)
    expect(ActiveStorage::Blob.exists?(blob.id)).to be(false)
    expect { described_class.perform_now(document.id) }.not_to(change { document.reload.purge_attempts })
  end

  it 'keeps the storage key and blob row after an external failure so deletion can retry' do
    document = create(:document, status: 'deleting')
    blob = document.file.blob
    service = blob.service
    allow(service).to receive(:delete).and_raise(IOError, 'private storage credentials')
    described_class.perform_now(document.id)
    expect(document.reload).to have_attributes(status: 'deleting', last_error: 'IOError')
    expect(ActiveStorage::Blob.exists?(blob.id)).to be(true)
    expect(document.file).to be_attached

    allow(service).to receive(:delete).and_call_original
    described_class.perform_now(document.id)
    expect(document.reload.status).to eq('deleted')
    expect(document.purge_attempts).to eq(2)
  end

  it 'preserves a rejection reason after clearing unsafe uploaded bytes' do
    document = create(:document, status: 'rejected', failure_code: 'file_type_mismatch')
    described_class.perform_now(document.id)
    expect(document.reload).to have_attributes(status: 'rejected', failure_code: 'file_type_mismatch')
    expect(document.file).not_to be_attached
    expect(document.purged_at).to be_present
  end

  it 'stops automatic retries after eight storage failures' do
    document = create(:document, status: 'deleting', purge_attempts: 7)
    allow(document.file.blob.service).to receive(:delete).and_raise(IOError)
    described_class.perform_now(document.id)
    expect(document.reload.status).to eq('purge_failed')
    allow(document.file.blob.service).to receive(:delete).and_call_original
    expect { document.retry_purge! }.to have_enqueued_job(described_class).with(document.id)
    described_class.perform_now(document.id)
    expect(document.reload.status).to eq('deleted')
  end

  it 'ignores a late failure after another worker has completed the purge' do
    document = create(:document, status: 'deleting', purge_attempts: 7)
    stale_document = Document.find(document.id)
    described_class.perform_now(document.id)
    expect(document.reload.status).to eq('deleted')

    described_class.new.send(:record_failure, stale_document, 8, IOError.new)

    expect(document.reload.status).to eq('deleted')
    expect(document.last_error).to be_nil
    expect(document.purged_at).to be_present
  end

  it 'ignores a stale attempt failure while a newer attempt is running' do
    document = create(:document, status: 'deleting', purge_attempts: 2)
    described_class.new.send(:record_failure, document, 1, IOError.new)
    expect(document.reload).to have_attributes(status: 'deleting', purge_attempts: 2, last_error: nil)
  end

  it 'does not exceed the purge budget when the previous attempt crashed' do
    document = create(:document, status: 'deleting', purge_attempts: 8)
    described_class.perform_now(document.id)
    expect(document.reload).to have_attributes(status: 'purge_failed', purge_attempts: 8,
                                               last_error: 'PurgeInterrupted')
    expect(document.file).to be_attached
  end
end

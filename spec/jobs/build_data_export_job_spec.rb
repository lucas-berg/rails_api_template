# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BuildDataExportJob do
  let(:owner) { create(:user) }
  let(:team) { Teams::Create.call(actor: owner, attributes: { name: 'Export recovery' }) }
  let(:export) { DataExports::Create.new(actor: owner, team: team).call }

  it 'tracks upload failures and purges the failed staging blob before retrying' do
    service = ActiveStorage::Blob.service
    allow(service).to receive(:upload).and_raise(IOError)
    described_class.perform_now(export.id)
    expect(export.reload.status).to eq('failed')
    expect(export.stage).to eq('failed')
    previous_blob = export.staging_blob
    expect(previous_blob).to be_present
    expect(export.file).not_to be_attached

    allow(service).to receive(:upload).and_call_original
    described_class.perform_now(export.id)
    expect(export.reload.status).to eq('ready')
    expect(export.staging_blob).to be_nil
    expect(ActiveStorage::Blob.exists?(previous_blob.id)).to be(false)
    expect(export.file).to be_attached
  end

  it 'does not publish after the requester loses permission during storage upload' do
    admin = create(:member, :admin, team: team)
    record = DataExports::Create.new(actor: admin.user, team: team).call
    service = ActiveStorage::Blob.service
    allow(service).to receive(:upload).and_wrap_original do |method, *args, **keywords|
      result = method.call(*args, **keywords)
      admin.update!(role: 'viewer')
      result
    end
    described_class.perform_now(record.id)
    expect(record.reload.status).to eq('failed')
    expect(record.attempts).to eq(5)
    expect(record.file).not_to be_attached
    staged_id = record.staging_blob_id
    CleanupDataExportsJob.perform_now
    expect(record.reload.staging_blob_id).to be_nil
    expect(ActiveStorage::Blob.exists?(staged_id)).to be(false)
  end

  it 'does not regenerate a ready export on duplicate execution' do
    described_class.perform_now(export.id)
    blob_id = export.reload.file.blob.id
    described_class.perform_now(export.id)
    expect(export.reload.file.blob.id).to eq(blob_id)
    expect(export.attempts).to eq(1)
  end
end

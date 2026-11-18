# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProcessDeletionJob do
  let(:user) { create(:user) }
  let(:team) { Teams::Create.call(actor: user, attributes: { name: 'Private storage cleanup' }) }
  let(:ledger_directory) { Dir.mktmpdir('deletion-storage-spec') }

  before { allow(Lifecycle::DeletionLedger).to receive(:directory).and_return(Pathname.new(ledger_directory)) }
  after { FileUtils.remove_entry(ledger_directory) }

  def uploaded_document
    file = uploaded_file
    document = Documents::Upload.new(actor: user, team: team).call(file: file)
    document.update!(status: 'ready', verified_at: Time.current, verified_content_type: 'image/jpeg')
    document
  ensure
    file&.tempfile&.close!
  end

  def uploaded_file
    temporary = Tempfile.new(['sample', '.jpg'])
    temporary.binmode
    temporary.write(Rails.root.join('spec/fixtures/files/sample.jpg').binread)
    temporary.rewind
    ActionDispatch::Http::UploadedFile.new(tempfile: temporary, filename: 'sample.jpg', type: 'image/jpeg')
  end

  def due_request
    deletion = Deletions::Request.call(actor: user, subject: team, password: user.password)
    deletion.update!(scheduled_at: 1.minute.ago)
    deletion
  end

  it 'removes document bytes, avatar pointers, private export artifacts, and team records' do
    document = uploaded_document
    user.update!(avatar_document_id: document.id)
    document_key = document.file.blob.key
    export = DataExports::Create.new(actor: user, team: team).call
    BuildDataExportJob.perform_now(export.id)
    export_key = export.reload.file.blob.key
    invitation = Invitations::Create.new(actor: user, team: team).call(email: 'remove@example.com')
    deletion = due_request

    described_class.perform_now(deletion.id)
    expect(deletion.reload.status).to eq('completed')
    expect(Document.exists?(document.id)).to be(false)
    expect(DataExport.exists?(export.id)).to be(false)
    expect(Invitation.exists?(invitation.id)).to be(false)
    expect(Notification.where(team: team)).to be_empty
    expect(MailDelivery.where(team_id: team.id)).to be_empty
    expect(user.reload.avatar_document_id).to be_nil
    expect(ActiveStorage::Blob.service.exist?(document_key)).to be(false)
    expect(ActiveStorage::Blob.service.exist?(export_key)).to be(false)
    expect(team.audit_events.where(action: 'deletion.completed')).to exist
  end

  it 'retains file metadata and storage keys on remote failure and resumes safely' do
    document = uploaded_document
    blob = document.file.blob
    deletion = due_request
    service = ActiveStorage::Blob.service
    allow(service).to receive(:delete).and_raise(IOError)
    described_class.perform_now(deletion.id)
    expect(deletion.reload.status).to eq('failed')
    expect(team.reload.status).to eq('deleting')
    expect(Document.exists?(document.id)).to be(true)
    expect(ActiveStorage::Blob.exists?(blob.id)).to be(true)
    expect(document.reload.purged_at).to be_nil

    allow(service).to receive(:delete).and_call_original
    described_class.perform_now(deletion.id)
    expect(deletion.reload.status).to eq('completed')
    expect(Document.exists?(document.id)).to be(false)
    expect(ActiveStorage::Blob.exists?(blob.id)).to be(false)
  end
end

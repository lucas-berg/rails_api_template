# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VerifyDocumentJob do
  it 'makes an actual PNG available only after verification' do
    document = create(:document, status: 'processing')
    expect(document).not_to be_ready
    described_class.perform_now(document.id)
    expect(document.reload).to be_ready
    expect(document.verified_content_type).to eq('image/png')
    expect { described_class.perform_now(document.id) }.not_to(change { document.reload.verified_at })
  end

  it 'rejects HTML declared as an image and queues removal of the quarantined bytes' do
    document = create(:document, status: 'processing', contents: '<script>alert(1)</script>')
    expect { described_class.perform_now(document.id) }.to have_enqueued_job(PurgeDocumentJob).with(document.id)
    expect(document.reload.status).to eq('rejected')
    expect(document.failure_code).to eq('file_type_mismatch')
  end

  it 'rejects truncated PNG files rather than trusting their signature' do
    document = create(:document, status: 'processing', contents: png_bytes.byteslice(0, 30))
    described_class.perform_now(document.id)
    expect(document.reload.status).to eq('rejected')
    expect(document.failure_code).to eq('invalid_file_content')
  end

  it 'rejects PNGs whose content checksum has been corrupted' do
    bytes = png_bytes.dup
    bytes.setbyte(45, bytes.getbyte(45) ^ 1)
    document = create(:document, status: 'processing', contents: bytes)
    described_class.perform_now(document.id)
    expect(document.reload.failure_code).to eq('invalid_file_content')
  end

  it 'checks actual stored size against the declared size and configured limit' do
    document = create(:document, status: 'processing', byte_size: 1)
    described_class.perform_now(document.id)
    expect(document.reload.failure_code).to eq('file_size_mismatch')
  end

  it 'checks member access again when the queued verification runs' do
    document = create(:document, status: 'processing')
    document.team.members.find_by!(user: document.uploader).update!(status: 'removed')
    described_class.perform_now(document.id)
    expect(document.reload.status).to eq('rejected')
    expect(document.failure_code).to eq('upload_unavailable')
  end

  it 'does not mark a file ready after the team is suspended' do
    document = create(:document, status: 'processing')
    document.team.update!(status: 'suspended')
    described_class.perform_now(document.id)
    expect(document.reload.status).to eq('rejected')
  end

  it 'does not resurrect a document deleted while verification was queued' do
    document = create(:document, status: 'deleting')
    described_class.perform_now(document.id)
    expect(document.reload.status).to eq('deleting')
  end

  it 'validates PDF bytes without labeling the check an antivirus scan' do
    document = create(:document, status: 'processing', contents: pdf_bytes,
                                 original_filename: 'sample.pdf', declared_content_type: 'application/pdf')
    described_class.perform_now(document.id)
    expect(document.reload).to be_ready
    expect(document.verified_content_type).to eq('application/pdf')
  end

  it 'validates JPEG frame and scan markers' do
    document = create(:document, status: 'processing', contents: jpeg_bytes,
                                 original_filename: 'sample.jpg', declared_content_type: 'image/jpeg')
    described_class.perform_now(document.id)
    expect(document.reload).to be_ready
    expect(document.verified_content_type).to eq('image/jpeg')
  end

  it 'rejects JPEG signatures without an image frame or scan' do
    document = create(:document, status: 'processing', contents: "\xFF\xD8\xFF\xE0garbage\xFF\xD9".b,
                                 original_filename: 'fake.jpg', declared_content_type: 'image/jpeg')
    described_class.perform_now(document.id)
    expect(document.reload.status).to eq('rejected')
  end
end

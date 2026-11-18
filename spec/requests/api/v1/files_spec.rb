# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Private files API', openapi: { security: [{ 'BearerAuth' => [] }] } do
  let(:owner) { create(:user) }
  let(:team) { Teams::Create.call(actor: owner, attributes: { name: 'Files team' }) }
  let(:headers) { auth_headers(owner) }

  def upload_file(file = multipart_upload, request_headers: headers)
    post "/api/v1/teams/#{team.id}/uploads", params: { file: }, headers: request_headers
    Document.find(json.dig(:data, :id)) if response.created?
  end

  def complete_file(document, request_headers: headers)
    post "/api/v1/teams/#{team.id}/uploads/#{document.id}/complete", headers: request_headers
  end

  def ready_file(file = multipart_upload)
    document = upload_file(file)
    complete_file(document)
    VerifyDocumentJob.perform_now(document.id)
    document.reload
  end

  it 'uploads, completes, verifies and privately streams a file' do
    document = upload_file
    expect(response).to have_http_status(:created)
    expect(json[:data]).to include(status: 'uploading', filename: 'sample.png')
    expect(json[:data]).not_to include(:key, :signed_id, :url)

    get "/api/v1/teams/#{team.id}/files/#{document.id}/download", headers: headers
    expect(response).to have_http_status(:conflict)

    complete_file(document)
    expect(response).to have_http_status(:accepted)
    VerifyDocumentJob.perform_now(document.id)

    get "/api/v1/teams/#{team.id}/files/#{document.id}/download", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.body.b).to eq(png_bytes)
    expect(response.headers['Content-Disposition']).to start_with('attachment;')
    expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
    expect(response.headers['Cache-Control']).to include('no-store')
  end

  it 'does not requeue an upload when completion is repeated' do
    document = upload_file
    complete_file(document)
    clear_enqueued_jobs
    complete_file(document)
    expect(response).to have_http_status(:accepted)
    expect(enqueued_jobs.select { |job| job[:job] == VerifyDocumentJob }).to be_empty
    VerifyDocumentJob.perform_now(document.id)
    complete_file(document)
    expect(response).to have_http_status(:ok)
  end

  it 'lists only files in the current team and returns file metadata' do
    document = ready_file
    create(:document)
    get "/api/v1/teams/#{team.id}/files", headers: headers
    expect(response).to have_http_status(:ok)
    expect(json[:data].pluck(:id)).to eq([document.id])
    get "/api/v1/teams/#{team.id}/files/#{document.id}", headers: headers
    expect(json.dig(:data, :content_type)).to eq('image/png')
  end

  it 'requires authentication and hides cross-team files even from a member of both teams' do
    document = ready_file
    get "/api/v1/teams/#{team.id}/files/#{document.id}/download"
    expect(response).to have_http_status(:unauthorized)
    other_team = Teams::Create.call(actor: owner, attributes: { name: 'Other team' })
    get "/api/v1/teams/#{other_team.id}/files/#{document.id}/download", headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it 'rejects signed IDs as upload inputs and disables unprotected storage routes' do
    document = ready_file
    signed_id = document.file.blob.signed_id
    post "/api/v1/teams/#{team.id}/uploads", params: { file: signed_id }, headers:, as: :json
    expect(response).to have_http_status(:bad_request)
    get "/rails/active_storage/blobs/redirect/#{signed_id}/sample.png"
    expect(response).to have_http_status(:not_found)
    post '/rails/active_storage/direct_uploads', params: {}, as: :json
    expect(response).to have_http_status(:not_found)
  end

  it 'rejects oversized uploads and forged content types' do
    allow(Document).to receive(:maximum_bytes).and_return(png_bytes.bytesize - 1)
    expect { upload_file }.not_to change(Document, :count)
    expect(response).to have_http_status(:conflict)
    allow(Document).to receive(:maximum_bytes).and_call_original
    document = upload_file(multipart_upload('<html>not a PNG</html>'))
    complete_file(document)
    VerifyDocumentJob.perform_now(document.id)
    expect(document.reload.status).to eq('rejected')
    get "/api/v1/teams/#{team.id}/files/#{document.id}/download", headers: headers
    expect(response).to have_http_status(:conflict)
  end

  it 'rejects completion by another member or after expiration' do
    document = upload_file
    other_member = create(:member, team:)
    complete_file(document, request_headers: auth_headers(other_member.user))
    expect(response).to have_http_status(:forbidden)
    travel 2.hours do
      complete_file(document)
      expect(response).to have_http_status(:conflict)
      expect(json.dig(:errors, 0, :code)).to eq('upload_expired')
    end
  end

  it 'allows viewers to download but not upload or delete' do
    document = ready_file
    viewer = create(:member, :viewer, team:)
    viewer_headers = auth_headers(viewer.user)
    get "/api/v1/teams/#{team.id}/files/#{document.id}/download", headers: viewer_headers
    expect(response).to have_http_status(:ok)
    upload_file(request_headers: viewer_headers)
    expect(response).to have_http_status(:forbidden)
    delete "/api/v1/teams/#{team.id}/files/#{document.id}", headers: viewer_headers
    expect(response).to have_http_status(:forbidden)
  end

  it 'restricts member deletion to own files and allows managers to remove files' do
    uploader = create(:member, team:)
    document = upload_file(request_headers: auth_headers(uploader.user))
    other_member = create(:member, team:)
    delete "/api/v1/teams/#{team.id}/files/#{document.id}", headers: auth_headers(other_member.user)
    expect(response).to have_http_status(:forbidden)
    delete "/api/v1/teams/#{team.id}/files/#{document.id}", headers: headers
    expect(response).to have_http_status(:no_content)
    PurgeDocumentJob.perform_now(document.id)
    delete "/api/v1/teams/#{team.id}/files/#{document.id}", headers: headers
    expect(response).to have_http_status(:no_content)
    expect(document.reload.status).to eq('deleted')
  end

  it 'previews verified images but never previews PDF content inline' do
    image = ready_file
    get "/api/v1/teams/#{team.id}/files/#{image.id}/preview", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.headers['Content-Disposition']).to start_with('inline;')
    expect(response.headers['Content-Security-Policy']).to include('sandbox')
    pdf = ready_file(multipart_upload(pdf_bytes, content_type: 'application/pdf', filename: 'sample.pdf'))
    get "/api/v1/teams/#{team.id}/files/#{pdf.id}/preview", headers: headers
    expect(response).to have_http_status(:conflict)
  end

  it 'requires a verified own image for an avatar and clears its reference on deletion' do
    document = upload_file
    patch "/api/v1/teams/#{team.id}/avatar", params: { avatar: { document_id: document.id } }, headers:, as: :json
    expect(response).to have_http_status(:conflict)
    complete_file(document)
    VerifyDocumentJob.perform_now(document.id)
    patch "/api/v1/teams/#{team.id}/avatar", params: { avatar: { document_id: document.id } }, headers:, as: :json
    expect(response).to have_http_status(:ok)
    expect(owner.reload.avatar_document_id).to eq(document.id)
    delete "/api/v1/teams/#{team.id}/files/#{document.id}", headers: headers
    expect(owner.reload.avatar_document_id).to be_nil
  end

  it 'clears an avatar through the authorized team endpoint' do
    document = ready_file
    patch "/api/v1/teams/#{team.id}/avatar", params: { avatar: { document_id: document.id } }, headers:, as: :json
    delete "/api/v1/teams/#{team.id}/avatar", headers: headers
    expect(response).to have_http_status(:no_content)
    expect(owner.reload.avatar_document_id).to be_nil
  end
end

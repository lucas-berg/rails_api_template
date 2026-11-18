# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Data exports API', openapi: { security: [{ 'BearerAuth' => [] }] } do
  let(:owner) { create(:user) }
  let(:team) { Teams::Create.call(actor: owner, attributes: { name: 'Export team' }) }
  let(:headers) { auth_headers(owner) }

  it 'accepts an asynchronous export with a private progress resource' do
    post "/api/v1/teams/#{team.id}/exports", headers: headers, as: :json
    expect(response).to have_http_status(:accepted)
    export = DataExport.find(json.dig(:data, :id))
    expect(response.headers['Location']).to end_with("/exports/#{export.id}")
    expect(json[:data]).to include(status: 'pending', stage: 'queued')
    expect(json[:data]).not_to include(:lease_token, :staging_blob_id, :url, :key)
  end

  it 'builds a private export and documents the file-content boundary' do
    export = DataExports::Create.new(actor: owner, team:).call
    BuildDataExportJob.perform_now(export.id)
    expect(export.reload.status).to eq('ready')
    get "/api/v1/teams/#{team.id}/exports/#{export.id}/download", headers: headers
    expect(response).to have_http_status(:ok)
    data = response.parsed_body
    expect(data['file_contents_included']).to be(false)
    expect(data['team']['id']).to eq(team.id)
    expect(data['members'].first['user']).not_to have_key('encrypted_password')
    expect(response.headers['Cache-Control']).to include('no-store')
  end

  it 'lists only exports requested by the current user in the selected team' do
    own = DataExports::Create.new(actor: owner, team:).call
    admin = create(:member, :admin, team:)
    DataExports::Create.new(actor: admin.user, team:).call
    other_team = Teams::Create.call(actor: owner, attributes: { name: 'Another export team' })
    DataExports::Create.new(actor: owner, team: other_team).call
    get "/api/v1/teams/#{team.id}/exports", headers: headers
    expect(response).to have_http_status(:ok)
    expect(json[:data].pluck(:id)).to eq([own.id])
    expect(json[:meta]).to include(page: 1, per_page: 20, total: 1)
  end

  it 'shows completed progress and expiry without disclosing storage identifiers' do
    export = DataExports::Create.new(actor: owner, team:).call
    BuildDataExportJob.perform_now(export.id)
    get "/api/v1/teams/#{team.id}/exports/#{export.id}", headers: headers
    expect(response).to have_http_status(:ok)
    expect(json[:data]).to include(id: export.id, status: 'ready', stage: 'completed')
    expect(json[:data][:expires_at]).to be_present
    expect(json[:data]).not_to include(:lease_token, :staging_blob_id, :url, :key)
  end

  it 'rechecks membership at execution and download time' do
    admin = create(:member, :admin, team: team)
    export = DataExports::Create.new(actor: admin.user, team: team).call
    member_headers = auth_headers(admin.user)
    Members::Remove.new(actor: owner, team: team).call(admin.id)
    BuildDataExportJob.perform_now(export.id)
    expect(export.reload.status).to eq('failed')
    expect(export.file).not_to be_attached
    get "/api/v1/teams/#{team.id}/exports/#{export.id}/download", headers: member_headers
    expect(response).to have_http_status(:not_found)
  end

  it 'rejects ordinary members and cross-team export IDs' do
    member = create(:member, team: team)
    post "/api/v1/teams/#{team.id}/exports", headers: auth_headers(member.user), as: :json
    expect(response).to have_http_status(:forbidden)
    export = DataExports::Create.new(actor: owner, team: team).call
    other_team = Teams::Create.call(actor: owner, attributes: { name: 'Other team' })
    get "/api/v1/teams/#{other_team.id}/exports/#{export.id}", headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it 'expires downloads after 24 hours and cleans their private attachment' do
    export = DataExports::Create.new(actor: owner, team: team).call
    BuildDataExportJob.perform_now(export.id)
    travel_to 25.hours.from_now do
      get "/api/v1/teams/#{team.id}/exports/#{export.id}/download", headers: headers
      expect(response).to have_http_status(:conflict)
      CleanupDataExportsJob.perform_now
      expect(export.reload.status).to eq('expired')
      expect(export.file).not_to be_attached
    end
  end
end

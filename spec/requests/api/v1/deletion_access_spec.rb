# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Access after irreversible team deletion', openapi: false do
  it 'withdraws team and file access even when the deletion ledger temporarily fails' do
    user = create(:user)
    team = Teams::Create.call(actor: user, attributes: { name: 'Frozen team' })
    document = create(:document, team:, uploader: user, status: 'ready', verified_at: Time.current,
                                 verified_content_type: 'image/png')
    headers = auth_headers(user)
    deletion = Deletions::Request.call(actor: user, subject: team, password: user.password)
    deletion.update!(scheduled_at: 1.minute.ago)
    allow(Lifecycle::DeletionLedger).to receive(:write!).and_raise(IOError)

    ProcessDeletionJob.perform_now(deletion.id)

    expect(deletion.reload.status).to eq('failed')
    expect(team.reload.status).to eq('deleting')
    expect(team.members).not_to be_empty
    expect(DocumentPolicy.new(user, document, team).allowed?(:download)).to be(false)
    expect(TeamPolicy.new(user, team)).not_to be_allowed(:read)

    get '/api/v1/teams', headers: headers
    expect(json[:data].pluck(:id)).not_to include(team.id)
    get "/api/v1/teams/#{team.id}/members", headers: headers
    expect(response).to have_http_status(:not_found)
    get "/api/v1/teams/#{team.id}/files/#{document.id}/download", headers: headers
    expect(response).to have_http_status(:not_found)
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Access after irreversible team deletion', openapi: false do
  it 'withdraws team access even when the deletion ledger temporarily fails' do
    user = create(:user)
    team = Teams::Create.call(actor: user, attributes: { name: 'Frozen team' })
    headers = auth_headers(user)
    deletion = Deletions::Request.call(actor: user, subject: team, password: user.password)
    deletion.update!(scheduled_at: 1.minute.ago)
    allow(Lifecycle::DeletionLedger).to receive(:write!).and_raise(IOError)

    ProcessDeletionJob.perform_now(deletion.id)

    expect(deletion.reload.status).to eq('failed')
    expect(team.reload.status).to eq('deleting')
    expect(team.members).not_to be_empty
    expect(Pundit.policy!(user, team)).not_to be_show

    get '/api/v1/teams', headers: headers
    expect(json[:data].pluck(:id)).not_to include(team.id)
    get "/api/v1/teams/#{team.id}/members", headers: headers
    expect(response).to have_http_status(:not_found)
  end
end

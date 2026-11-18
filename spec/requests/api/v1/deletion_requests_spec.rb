# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Deletion requests API', openapi: { security: [{ 'BearerAuth' => [] }] } do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:team) { Teams::Create.call(actor: user, attributes: { name: 'Delete team' }) }

  it 'requires the current password and freezes team writes during the seven-day cooling period',
     openapi: { request_pattern: 'POST /api/v1/teams/{team_id}/deletion_request' } do
    post "/api/v1/teams/#{team.id}/deletion_request", params: { current_password: 'wrong' }, headers: headers, as: :json
    expect(response).to have_http_status(:forbidden)
    post "/api/v1/teams/#{team.id}/deletion_request", params: { current_password: user.password }, headers: headers,
                                                      as: :json
    expect(response).to have_http_status(:accepted)
    expect(team.reload.status).to eq('deletion_pending')
    expect(Time.iso8601(json.dig(:data, :scheduled_at))).to be_within(2.seconds).of(7.days.from_now)
    patch "/api/v1/teams/#{team.id}", params: { team: { name: 'Forbidden write' } }, headers: headers, as: :json
    expect(response).to have_http_status(:conflict)
  end

  it 'shows the requested deletion schedule without exposing the encrypted completion recipient' do
    deletion = Deletions::Request.call(actor: user, subject: team, password: user.password)
    get "/api/v1/deletion_requests/#{deletion.id}", headers: headers
    expect(response).to have_http_status(:ok)
    expect(json[:data]).to include(id: deletion.id, status: 'pending', stage: 'requested', subject_type: 'Team')
    expect(json[:data][:scheduled_at]).to be_present
    expect(json[:data]).not_to include(:encrypted_recipient, :recipient)
  end

  it 'allows the requester to cancel with their password and restores the previous team status' do
    team.update!(status: 'suspended')
    deletion = Deletions::Request.call(actor: user, subject: team, password: user.password)
    get "/api/v1/deletion_requests/#{deletion.id}", headers: headers
    expect(response).to have_http_status(:ok)
    delete "/api/v1/deletion_requests/#{deletion.id}", params: { current_password: user.password }, headers: headers,
                                                       as: :json
    expect(response).to have_http_status(:ok)
    expect(deletion.reload.status).to eq('canceled')
    expect(deletion.encrypted_recipient).to be_nil
    expect(team.reload.status).to eq('suspended')
  end

  it 'rejects deleting a last owner account' do
    team
    post '/api/v1/user/deletion_request', params: { current_password: user.password }, headers: headers, as: :json
    expect(response).to have_http_status(:conflict)
    expect(json.dig(:errors, 0, :code)).to eq('last_owner')
  end

  it 'keeps account login available for cancellation until processing starts',
     openapi: { request_pattern: 'POST /api/v1/user/deletion_request' } do
    post '/api/v1/user/deletion_request', params: { current_password: user.password }, headers: headers, as: :json
    expect(response).to have_http_status(:accepted)
    deletion = DeletionRequest.find(json.dig(:data, :id))
    expect(user.reload).to be_active_for_authentication
    delete "/api/v1/deletion_requests/#{deletion.id}", params: { current_password: user.password }, headers: headers,
                                                       as: :json
    expect(response).to have_http_status(:ok)
  end

  it 'hides other users requests and rejects cancellation after processing starts' do
    deletion = Deletions::Request.call(actor: user, subject: team, password: user.password)
    get "/api/v1/deletion_requests/#{deletion.id}", headers: auth_headers(create(:user))
    expect(response).to have_http_status(:not_found)
    deletion.update!(status: 'processing', stage: 'files')
    delete "/api/v1/deletion_requests/#{deletion.id}", params: { current_password: user.password }, headers: headers,
                                                       as: :json
    expect(response).to have_http_status(:conflict)
  end
end

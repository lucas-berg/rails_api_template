# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Teams API', openapi: { security: [{ 'BearerAuth' => [] }] } do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:team) { Teams::Create.call(actor: user, attributes: { name: 'Primary team' }) }

  it 'creates a team with an owner and audit event atomically' do
    post '/api/v1/teams', params: { team: { name: 'New team', timezone: 'UTC', locale: 'en' } }, headers:, as: :json

    expect(response).to have_http_status(:created)
    created = Team.find(json.dig(:data, :id))
    expect(created.active_members.find_by!(user:)).to be_owner
    expect(created.audit_events.pluck(:action)).to eq(['team.created'])
    expect(json.dig(:data, :slug)).to start_with('new-team-')
  end

  it 'only lists teams for the current active member with capped pagination' do
    team
    create(:team)
    get '/api/v1/teams', params: { per_page: 500 }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(json[:data].pluck(:id)).to eq([team.id])
    expect(json[:meta]).to include(per_page: 100, total: 1)
    expect(Current.team).to be_nil
  end

  it 'returns the current team and updates permitted settings' do
    get "/api/v1/teams/#{team.id}", headers: headers
    expect(response).to have_http_status(:ok)

    patch "/api/v1/teams/#{team.id}", params: { team: { name: 'Renamed' } }, headers:, as: :json
    expect(response).to have_http_status(:ok)
    expect(team.reload.name).to eq('Renamed')
  end

  it 'hides another team and rejects forged ownership attributes' do
    other = create(:team)
    get "/api/v1/teams/#{other.id}", headers: headers
    expect(response).to have_http_status(:not_found)

    post '/api/v1/teams', params: { team: { name: 'Forged', user_id: user.id, status: 'active' } }, headers:, as: :json
    expect(response).to have_http_status(:bad_request)
    expect(json.dig(:errors, 0, :code)).to eq('invalid_parameter')
  end

  it 'requires authentication with the new error envelope' do
    get '/api/v1/teams'
    expect(response).to have_http_status(:unauthorized)
    expect(json).to include(:request_id)
    expect(json.dig(:errors, 0, :code)).to eq('unauthenticated')
  end

  it 'rejects an invalid timezone without partially creating the team' do
    expect {
      post '/api/v1/teams', params: { team: { name: 'Invalid', timezone: 'not/a/timezone' } }, headers:, as: :json
    }.not_to change(Team, :count)
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'rejects team writes by a viewer and suspended teams' do
    viewer = create(:member, :viewer, team:)
    patch "/api/v1/teams/#{team.id}", params: { team: { name: 'No' } }, headers: auth_headers(viewer.user), as: :json
    expect(response).to have_http_status(:forbidden)

    team.update!(status: 'suspended')
    patch "/api/v1/teams/#{team.id}", params: { team: { name: 'No' } }, headers:, as: :json
    expect(response).to have_http_status(:conflict)
    expect(json.dig(:errors, 0, :code)).to eq('team_suspended')
  end

  it 'reads settings, validates updates, and rejects unknown fields' do
    get "/api/v1/teams/#{team.id}/settings", headers: headers
    expect(response).to have_http_status(:ok)
    expect(json[:data]).to include(timezone: 'UTC', locale: 'en')

    patch "/api/v1/teams/#{team.id}/settings", params: { settings: { locale: 'zh-CN' } }, headers:, as: :json
    expect(response).to have_http_status(:ok)
    expect(team.reload.locale).to eq('zh-CN')

    patch "/api/v1/teams/#{team.id}/settings", params: { settings: { secret_key: 'bad' } }, headers:, as: :json
    expect(response).to have_http_status(:bad_request)
  end

  it 'only allows managers to read team audit events' do
    get "/api/v1/teams/#{team.id}/audit_events", headers: headers
    expect(response).to have_http_status(:ok)
    expect(json[:data].pluck(:action)).to include('team.created')

    member = create(:member, team:)
    get "/api/v1/teams/#{team.id}/audit_events", headers: auth_headers(member.user)
    expect(response).to have_http_status(:forbidden)
  end
end

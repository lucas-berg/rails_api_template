# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Avatar selection API', openapi: { security: [{ 'BearerAuth' => [] }] } do
  let(:user) { create(:user) }
  let(:team) { Teams::Create.call(actor: user, attributes: { name: 'Avatar team' }) }
  let(:headers) { auth_headers(user) }
  let(:document) do
    create(:document, team:, uploader: user, status: 'ready', verified_at: Time.current,
                      verified_content_type: 'image/png')
  end

  it 'returns the selected verified avatar to a fresh login' do
    user.update!(avatar_document_id: document.id)
    post '/users/sign_in', params: { user: { email: user.email, password: user.password } }, as: :json
    token = response.headers['Authorization']

    get "/api/v1/teams/#{team.id}/avatar", headers: { 'Authorization' => token }

    expect(response).to have_http_status(:ok)
    expect(json[:data]).to include(id: document.id, status: 'ready', content_type: 'image/png')
    expect(json[:data]).not_to include(:key, :signed_id, :url)
  end

  it 'does not expose a selected avatar from another team' do
    other_team = create(:team)
    create(:member, team: other_team, user:)
    user.update!(avatar_document_id: document.id)

    get "/api/v1/teams/#{other_team.id}/avatar", headers: headers

    expect(response).to have_http_status(:ok)
    expect(json[:data]).to be_nil
  end

  it 'hides a selected avatar after membership is removed' do
    user.update!(avatar_document_id: document.id)
    team.members.find_by!(user:).update!(status: :removed)

    get "/api/v1/teams/#{team.id}/avatar", headers: headers

    expect(response).to have_http_status(:not_found)
  end

  it 'does not expose an avatar which is no longer ready' do
    user.update!(avatar_document_id: document.id)
    document.update!(status: 'deleting')

    get "/api/v1/teams/#{team.id}/avatar", headers: headers

    expect(response).to have_http_status(:ok)
    expect(json[:data]).to be_nil
  end
end

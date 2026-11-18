# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API sessions', openapi: { security: [{ 'BearerAuth' => [] }] } do
  let(:user) { create(:user) }
  let!(:headers) { auth_headers(user) }

  it 'lists only the current user active sessions without token identifiers' do
    other = create(:user)
    auth_headers(other)
    get api_v1_auth_sessions_path, headers: headers

    expect(response).to have_http_status(:ok)
    expect(json.fetch(:data).pluck(:id)).to eq(user.auth_sessions.pluck(:id))
    expect(json.fetch(:data).first.keys).to match_array(%w[id created_at expires_at last_used_at])
  end

  it 'revokes another API session without signing out this one' do
    other_headers = auth_headers(user)
    session = user.auth_sessions.order(:id).last
    delete api_v1_auth_session_path(session), headers: headers

    expect(response).to have_http_status(:no_content)
    get api_v1_user_path, headers: other_headers
    expect(response).to have_http_status(:unauthorized)
    get api_v1_user_path, headers: headers
    expect(response).to have_http_status(:ok)
  end

  it 'does not revoke another user session' do
    other = create(:user)
    auth_headers(other)
    session = other.auth_sessions.first
    delete api_v1_auth_session_path(session), headers: headers

    expect(response).to have_http_status(:not_found)
    expect(session.reload.revoked_at).to be_nil
  end

  it 'requires a bearer token' do
    get api_v1_auth_sessions_path
    expect(response).to have_http_status(:unauthorized)
  end
end

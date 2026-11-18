# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Account security', openapi: false do
  let(:user) { create(:user) }

  it 'issues a registered JWT with an absolute lifetime of 90 days' do
    post user_session_path, params: { user: { email: user.email, password: user.password } }, as: :json

    token = response.headers.fetch('Authorization').delete_prefix('Bearer ')
    payload = Warden::JWTAuth::TokenDecoder.new.call(token)
    expect(payload.fetch('exp') - payload.fetch('iat')).to eq(90.days.to_i)
    session = user.auth_sessions.sole
    expect(session.jti_digest).to eq(Digest::SHA256.hexdigest(payload.fetch('jti')))
    expect(session.expires_at.to_i).to eq(payload.fetch('exp'))
    headers = { 'Authorization' => "Bearer #{token}" }

    travel_to(Time.zone.at(payload.fetch('exp')) - 1.second) do
      get api_v1_user_path, headers: headers
      expect(response).to have_http_status(:ok)
      expect(session.reload.expires_at.to_i).to eq(payload.fetch('exp'))
    end
    travel_to(Time.zone.at(payload.fetch('exp'))) do
      get api_v1_user_path, headers: headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  it 'rejects an otherwise valid token with no registered session' do
    headers = Devise::JWT::TestHelpers.auth_headers({}, user)
    get api_v1_user_path, headers: headers
    expect(response).to have_http_status(:unauthorized)
  end

  it 'records request device metadata and exposes it only through the owner session list' do
    post user_session_path,
         params: { user: { email: user.email, password: user.password,
                           user_agent: 'forged-body-agent', ip_address: '198.51.100.40' } },
         headers: { 'User-Agent' => 'ExampleClient/1.0', 'REMOTE_ADDR' => '203.0.113.7' }, as: :json
    expect(response).to have_http_status(:ok)
    token = response.headers.fetch('Authorization')
    session = user.auth_sessions.sole
    expect(session.user_agent).to eq('ExampleClient/1.0')
    expect(session.ip_address.to_s).to eq('203.0.113.7')

    get api_v1_auth_sessions_path, headers: { 'Authorization' => token }
    expect(json.fetch(:data).first).to include(user_agent: 'ExampleClient/1.0', ip_address: '203.0.113.7')

    other = create(:user)
    get api_v1_auth_sessions_path, headers: auth_headers(other)
    expect(json.fetch(:data).pluck(:id)).not_to include(session.id)
    expect(response.body).not_to include('ExampleClient/1.0', '203.0.113.7')
  end

  it 'does not create API sessions for HTML sign-ins' do
    expect {
      post user_session_path, params: { user: { email: user.email, password: user.password } }
    }.not_to change(AuthSession, :count)
    expect(response).to redirect_to(account_path)
    expect(response.headers['Authorization']).to be_nil
  end

  it 'revokes every old JWT when the password changes' do
    first = auth_headers(user)
    second = auth_headers(user)
    user.update!(password: 'A-new-secure-password!')

    [first, second].each do |headers|
      get api_v1_user_path, headers: headers
      expect(response).to have_http_status(:unauthorized)
    end
    expect(user.auth_sessions.where(revoked_at: nil)).to be_empty
  end

  it 'revokes JWTs on password reset and prevents resetting twice with the same link' do
    headers = auth_headers(user)
    token = user.send_reset_password_instructions
    attributes = { reset_password_token: token, password: 'A-new-secure-password!',
                   password_confirmation: 'A-new-secure-password!' }
    put user_password_path, params: { user: attributes }, as: :json
    expect(response).to have_http_status(:no_content)
    get api_v1_user_path, headers: headers
    expect(response).to have_http_status(:unauthorized)

    put user_password_path, params: { user: attributes }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'does not revive old JWTs after a suspended account is restored' do
    headers = auth_headers(user)
    user.suspend!
    get api_v1_user_path, headers: headers
    expect(response).to have_http_status(:unauthorized)

    user.restore!
    get api_v1_user_path, headers: headers
    expect(response).to have_http_status(:unauthorized)
  end

  it 'invalidates a browser session even if suspension is lifted before its next request' do
    post user_session_path, params: { user: { email: user.email, password: user.password } }
    user.suspend!
    user.restore!
    get account_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it 'invalidates an existing browser session after a password reset' do
    post user_session_path, params: { user: { email: user.email, password: user.password } }
    token = user.send_reset_password_instructions
    User.reset_password_by_token(reset_password_token: token, password: 'Changed-from-another-device!',
                                 password_confirmation: 'Changed-from-another-device!')
    get account_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it 'schedules account deletion after password confirmation without immediately removing the account' do
    headers = auth_headers(user)
    expect {
      delete user_registration_path, headers: headers, params: { current_password: user.password }, as: :json
    }.not_to change(User, :count)

    expect(response).to have_http_status(:accepted)
    expect(json.fetch(:data).fetch(:status)).to eq('pending')
    expect(response.headers['Location']).to eq("/api/v1/deletion_requests/#{json.fetch(:data).fetch(:id)}")
    get api_v1_user_path, headers: headers
    expect(response).to have_http_status(:ok)
  end

  it 'never serializes authentication internals, including when explicitly requested' do
    data = user.serializable_hash(only: [:encrypted_password], methods: [:password])
    expect(data.keys).to match_array(User::PUBLIC_ATTRIBUTES)
    expect(data.values).not_to include(user.password, user.encrypted_password)
  end
end

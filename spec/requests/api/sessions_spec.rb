# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'JSON sessions' do
  let(:user) { create(:user) }

  it 'signs in with JSON credentials and returns a bearer token' do
    post user_session_path, params: { user: { email: user.email, password: user.password } }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.headers['Authorization']).to start_with('Bearer ')
    expect(response.headers['Set-Cookie']).to be_nil
    expect(json.fetch(:user).fetch(:email)).to eq(user.email)
  end

  it 'rejects incorrect credentials' do
    post user_session_path, params: { user: { email: user.email, password: 'incorrect' } }, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(response.headers['Authorization']).to be_nil
  end

  it 'signs out the current API session', openapi: { security: [{ 'BearerAuth' => [] }] } do
    delete destroy_user_session_path, headers: auth_headers(user), as: :json

    expect(response).to have_http_status(:no_content)
  end

  it 'revokes only the token used to sign out', openapi: false do
    first_device = auth_headers(user)
    second_device = auth_headers(user)

    delete destroy_user_session_path(format: :json), headers: first_device
    expect(response).to have_http_status(:no_content)

    get api_v1_user_path, headers: first_device
    expect(response).to have_http_status(:unauthorized)

    get api_v1_user_path, headers: second_device
    expect(response).to have_http_status(:ok)
  end
end

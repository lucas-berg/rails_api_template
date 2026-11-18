# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User profile API', openapi: { security: [{ 'BearerAuth' => [] }] } do
  let(:user) { create(:user, uid: nil) }
  let(:headers) { auth_headers(user) }

  it 'returns the signed-in user' do
    get api_v1_user_path, headers: headers

    expect(response).to have_http_status(:ok)
    expect(json.fetch(:user)).to include(email: user.email, username: user.username)
    expect(json.fetch(:user)).not_to have_key(:encrypted_password)
  end

  it 'updates the signed-in profile' do
    patch api_v1_user_path, params: { user: { username: 'sample' } }, headers: headers, as: :json

    expect(response).to have_http_status(:ok)
    expect(json.fetch(:user).fetch(:username)).to eq('sample')
    expect(user.reload.username).to eq('sample')
  end

  it 'updates the email with the current password' do
    put api_v1_user_path, params: { user: { email: 'new@example.com', current_password: user.password } },
                          headers: headers, as: :json

    expect(response).to have_http_status(:ok)
    expect(json.fetch(:user)).to include(email: 'new@example.com', uid: 'new@example.com')
  end

  it 'requires the current password for an email change' do
    previous_email = user.email
    put api_v1_user_path, params: { user: { email: 'new@example.com' } }, headers: headers, as: :json

    expect(response).to have_http_status(:bad_request)
    expect(json.fetch(:errors)).to be_present
    expect(user.reload.email).to eq(previous_email)
  end

  it 'returns an error for missing parameters' do
    patch api_v1_user_path, params: {}, headers: headers, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(json.fetch(:errors)).to be_present
  end

  it 'requires a bearer token even when the browser has signed in', openapi: false do
    post user_session_path, params: { user: { email: user.email, password: user.password } }
    expect(response).to redirect_to(account_path)

    get api_v1_user_path
    expect(response).to have_http_status(:unauthorized)

    get account_path
    expect(response).to have_http_status(:ok)
  end

  it 'requires authentication' do
    get api_v1_user_path

    expect(response).to have_http_status(:unauthorized)
  end
end

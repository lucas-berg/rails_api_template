# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Email confirmations' do
  it 'rejects sign-in until the address is confirmed',
     openapi: { request_pattern: 'GET /users/confirmation' } do
    user = create(:user, :unconfirmed)
    post user_session_path, params: { user: { email: user.email, password: user.password } }, as: :json
    expect(response).to have_http_status(:unauthorized)
    expect(response.headers['Authorization']).to be_nil

    get user_confirmation_path, params: { confirmation_token: user.confirmation_token },
                                headers: { 'ACCEPT' => 'application/json' }
    expect(response).to have_http_status(:ok)
    expect(user.reload).to be_confirmed

    post user_session_path, params: { user: { email: user.email, password: user.password } }, as: :json
    expect(response).to have_http_status(:ok)
  end

  it 'does not confirm a second time with the same link', openapi: false do
    user = create(:user, :unconfirmed)
    token = user.confirmation_token
    get user_confirmation_path, params: { confirmation_token: token }, headers: { 'ACCEPT' => 'application/json' }
    get user_confirmation_path, params: { confirmation_token: token }, headers: { 'ACCEPT' => 'application/json' }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'rejects confirmation after 24 hours', openapi: false do
    user = create(:user, :unconfirmed)
    travel 24.hours + 1.second do
      get user_confirmation_path, params: { confirmation_token: user.confirmation_token },
                                  headers: { 'ACCEPT' => 'application/json' }
      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload).not_to be_confirmed
    end
  end

  it 'rejects an old link after a new email change has replaced it', openapi: false do
    user = create(:user, :unconfirmed, uid: nil)
    original_token = user.confirmation_token
    get user_confirmation_path, params: { confirmation_token: original_token },
                                headers: { 'ACCEPT' => 'application/json' }
    previous_email = user.reload.email
    user.update!(email: 'replacement@example.com')
    replacement_token = user.confirmation_token

    get user_confirmation_path, params: { confirmation_token: original_token },
                                headers: { 'ACCEPT' => 'application/json' }
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.email).to eq(previous_email)

    get user_confirmation_path, params: { confirmation_token: replacement_token },
                                headers: { 'ACCEPT' => 'application/json' }
    expect(response).to have_http_status(:ok)
    expect(user.reload.email).to eq('replacement@example.com')
  end

  it 'uses the same resend response for unknown and registered addresses' do
    user = create(:user, :unconfirmed)
    post user_confirmation_path, params: { user: { email: user.email } }, as: :json
    known_status = response.status
    known_body = response.body

    post user_confirmation_path, params: { user: { email: 'unknown@example.com' } }, as: :json
    expect(response.status).to eq(known_status)
    expect(response.body).to eq(known_body)
  end
end

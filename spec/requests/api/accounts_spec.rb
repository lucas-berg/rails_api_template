# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'JSON accounts' do
  it 'registers an account' do
    expect {
      post user_registration_path, params: { user: { email: 'person@example.com', password: 'sample-password' } },
                                   as: :json
    }.to change(User, :count).by(1)
    expect(response).to have_http_status(:created)
    expect(response.headers['Set-Cookie']).to be_nil
    expect(json.keys).to match_array(%w[id email first_name last_name username created_at updated_at provider uid])
  end

  it 'requests password reset instructions' do
    user = create(:user)
    expect {
      post user_password_path, params: { user: { email: user.email } }, as: :json
    }.to change(MailDelivery, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(json).to be_empty
  end

  it 'returns the same reset response for an unregistered address', openapi: false do
    expect {
      post user_password_path, params: { user: { email: 'unregistered@example.com' } }, as: :json
    }.not_to change(MailDelivery, :count)
    expect(response).to have_http_status(:created)
    expect(json).to be_empty
  end

  it 'sets a new password using a reset token' do
    user = create(:user)
    token = user.send_reset_password_instructions
    put user_password_path, params: { user: { reset_password_token: token, password: 'new-sample-password',
                                              password_confirmation: 'new-sample-password' } }, as: :json

    expect(response).to have_http_status(:no_content)
    expect(response.body).to be_empty
    expect(user.reload).to be_valid_password('new-sample-password')
  end
end

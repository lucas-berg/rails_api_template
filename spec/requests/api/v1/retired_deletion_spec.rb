# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Retired deletion endpoints', openapi: false do
  [
    [:post, '/api/v1/user/deletion_request'],
    [:post, '/api/v1/teams/1/deletion_request'],
    [:get, '/api/v1/deletion_requests/1'],
    [:delete, '/api/v1/deletion_requests/1']
  ].each do |method, path|
    it "returns 404 for #{method.upcase} #{path}" do
      public_send(method, path)

      expect(response).to have_http_status(:not_found)
    end
  end

  it 'does not fall back to Devise hard deletion for an authenticated account' do
    user = create(:user)
    headers = auth_headers(user)

    expect {
      delete user_registration_path, params: { current_password: user.password }, headers:, as: :json
    }.not_to change(User, :count)

    expect(response).to have_http_status(:not_found)
    get api_v1_user_path, headers: headers
    expect(response).to have_http_status(:ok)
    expect(user.reload).to be_active
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User preferences API', openapi: { security: [{ 'BearerAuth' => [] }] } do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  it 'updates permitted preferences without modifying global settings' do
    patch '/api/v1/user', params: { user: { preferences: { locale: 'zh-CN', timezone: 'Asia/Shanghai' } } }, headers:,
                          as: :json
    expect(response).to have_http_status(:ok)
    expect(json.dig(:user, :preferences)).to eq('locale' => 'zh-CN', 'timezone' => 'Asia/Shanghai')
  end

  it 'rejects unknown preference keys and invalid timezone types' do
    patch '/api/v1/user', params: { user: { preferences: { role: 'owner' } } }, headers:, as: :json
    expect(response).to have_http_status(:bad_request)
    expect(user.reload.preferences).to eq({})

    patch '/api/v1/user', params: { user: { preferences: { timezone: 'invalid' } } }, headers:, as: :json
    expect(response).to have_http_status(:bad_request)
  end
end

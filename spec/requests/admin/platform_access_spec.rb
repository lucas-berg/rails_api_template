# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Platform access' do
  let(:support) { create(:admin_user, :support) }
  let(:operator) { create(:admin_user) }
  let(:team) { create(:team) }

  it 'allows support to read approved resources but rejects custom writes' do
    sign_in support
    get '/admin/teams'
    expect(response).to have_http_status(:ok)
    post "/admin/teams/#{team.id}/suspend", params: { reason: 'Support request' }
    expect(response).to have_http_status(:forbidden)
    expect(team.reload).to be_active
  end

  it 'denies support creation and updates of administrators' do
    sign_in support
    post '/admin/admin_users', params: { admin_user: { email: 'new@example.com', password: 'test-password' } }
    expect(response).to have_http_status(:forbidden)
    patch "/admin/admin_users/#{support.id}", params: { admin_user: { role: 'super_admin' } }
    expect(response).to have_http_status(:forbidden)
    expect(support.reload).to be_support
  end

  it 'audits team suspension and restoration' do
    sign_in operator
    post "/admin/teams/#{team.id}/suspend", params: { reason: 'Investigate abuse' }
    expect(response).to have_http_status(:found)
    expect(team.reload).to be_suspended
    expect(team.audit_events.last).to have_attributes(actor_type: 'AdminUser', actor_id: operator.id,
                                                      reason: 'Investigate abuse', action: 'team.suspended')
    post "/admin/teams/#{team.id}/restore", params: { reason: 'Resolved' }
    expect(team.reload).to be_active
  end

  it 'invalidates old API credentials on suspension and does not restore them' do
    user = create(:user)
    headers = auth_headers(user)
    sign_in operator
    post "/admin/users/#{user.id}/suspend", params: { reason: 'Compromised account' }
    expect(response).to have_http_status(:found)
    post "/admin/users/#{user.id}/restore", params: { reason: 'Identity checked' }
    get '/api/v1/user', headers: headers
    expect(response).to have_http_status(:unauthorized)
  end

  it 'does not expose token digests or encrypted email payloads in show pages' do
    user = create(:user)
    auth_headers(user)
    session = user.auth_sessions.last
    sign_in support
    get "/admin/auth_sessions/#{session.id}"
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(session.jti_digest)
    delivery = MailDelivery.enqueue_devise(user, :reset_password_instructions, ['private-reset-token'])
    get "/admin/mail_deliveries/#{delivery.id}"
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('private-reset-token', delivery.encrypted_payload)
  end

  it 'only super administrators can open independently mounted tools' do
    sign_in support
    get '/admin/feature-flags'
    expect(response).not_to have_http_status(:ok)
    get '/admin/jobs'
    expect(response).not_to have_http_status(:ok)
  end

  it 'requires a reason for platform state changes' do
    sign_in operator
    post "/admin/teams/#{team.id}/suspend"
    expect(response).to have_http_status(:bad_request)
    expect(team.reload).to be_active
  end

  it 'defaults unknown actions and resources to denied' do
    adapter = PlatformAuthorization.new(nil, operator)
    expect(adapter.authorized?(:destroy, team)).to be(false)
    expect(adapter.authorized?(:create, Setting)).to be(false)
    expect(adapter.authorized?(:unknown, team)).to be(false)
    expect(adapter.scope_collection(Setting.all)).to be_empty
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Invitations API', openapi: { security: [{ 'BearerAuth' => [] }] } do
  let(:owner) { create(:user) }
  let(:team) { Teams::Create.call(actor: owner, attributes: { name: 'Invitations' }) }
  let(:headers) { auth_headers(owner) }
  let(:recipient) { create(:user) }

  def create_invitation(role: 'member')
    post "/api/v1/teams/#{team.id}/invitations", params: { invitation: { email: recipient.email.upcase, role: } },
                                                 headers:, as: :json
    expect(response).to have_http_status(:created)
    invitation_response
  end

  def invitation_response
    [Invitation.find(json.dig(:data, :id)), MailDelivery.where(kind: 'invitation').last.payload.fetch('token')]
  end

  it 'creates and lists an invitation without leaking its token' do
    invitation, token = create_invitation
    expect(invitation.normalized_email).to eq(recipient.email)
    expect(invitation.token_matches?(token)).to be(true)
    expect(json[:data]).not_to have_key(:token_digest)
    get "/api/v1/teams/#{team.id}/invitations", headers: headers
    expect(response).to have_http_status(:ok)
    expect(json[:data].pluck(:id)).to eq([invitation.id])
  end

  it 'accepts an invitation once and safely replays for an existing member' do
    invitation, token = create_invitation
    recipient_headers = auth_headers(recipient)
    expect {
      post '/api/v1/invitations/accept', params: { token: }, headers: recipient_headers, as: :json
    }.to change(Member, :count).by(1)
    expect(response).to have_http_status(:ok)
    expect(invitation.reload.accepted_at).to be_present

    expect {
      post '/api/v1/invitations/accept', params: { token: }, headers: recipient_headers, as: :json
    }.not_to change(Member, :count)
    expect(response).to have_http_status(:ok)
    expect(team.audit_events.where(action: 'invitation.accepted').count).to eq(1)
  end

  it 'requires the verified target email and rejects an expired invitation' do
    invitation, token = create_invitation
    post '/api/v1/invitations/accept', params: { token: }, headers:, as: :json
    expect(response).to have_http_status(:forbidden)

    invitation.update!(expires_at: 1.minute.ago)
    post '/api/v1/invitations/accept', params: { token: }, headers: auth_headers(recipient), as: :json
    expect(response).to have_http_status(:conflict)
    expect(team.active_members.exists?(user: recipient)).to be(false)
  end

  it 'rotates the token when resending and rejects the previous link',
     openapi: { request_pattern: 'POST /api/v1/teams/{team_id}/invitations/{id}/resend' } do
    invitation, old_token = create_invitation
    post "/api/v1/teams/#{team.id}/invitations/#{invitation.id}/resend", headers:, as: :json
    expect(response).to have_http_status(:ok)
    new_token = MailDelivery.where(kind: 'invitation').last.payload.fetch('token')
    expect(new_token).not_to eq(old_token)

    post '/api/v1/invitations/accept', params: { token: old_token }, headers: auth_headers(recipient), as: :json
    expect(response).to have_http_status(:not_found)
  end

  it 'revokes an invitation and rejects its existing link',
     openapi: { request_pattern: 'DELETE /api/v1/teams/{team_id}/invitations/{id}' } do
    invitation, token = create_invitation
    delete "/api/v1/teams/#{team.id}/invitations/#{invitation.id}", headers: headers
    expect(response).to have_http_status(:no_content)
    post '/api/v1/invitations/accept', params: { token: }, headers: auth_headers(recipient), as: :json
    expect(response).to have_http_status(:conflict)
  end

  it 'does not allow duplicate pending invitations, but allows a new invitation after expiry' do
    invitation, = create_invitation
    post "/api/v1/teams/#{team.id}/invitations", params: { invitation: { email: recipient.email } }, headers:, as: :json
    expect(response).to have_http_status(:conflict)
    invitation.update!(expires_at: 1.minute.ago)
    create_invitation
    expect(invitation.reload.revoked_at).to be_present
  end

  it 'prevents admin invitations from granting another admin role and hides cross-team invitations' do
    admin = create(:member, :admin, team:)
    post "/api/v1/teams/#{team.id}/invitations", params: { invitation: { email: recipient.email, role: 'admin' } },
                                                 headers: auth_headers(admin.user), as: :json
    expect(response).to have_http_status(:forbidden)

    invitation = create(:invitation)
    delete "/api/v1/teams/#{team.id}/invitations/#{invitation.id}", headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it 'rejects a pending invitation after its inviter loses invitation permissions' do
    admin = create(:member, :admin, team:)
    invitation = Invitations::Create.new(actor: admin.user, team:).call(email: recipient.email)
    token = MailDelivery.where(kind: 'invitation').last.payload.fetch('token')
    admin.update!(role: 'viewer')
    post '/api/v1/invitations/accept', params: { token: }, headers: auth_headers(recipient), as: :json
    expect(response).to have_http_status(:conflict)
    expect(invitation.reload.accepted_at).to be_nil
  end

  it 'does not restore membership by replaying an already accepted invitation after removal' do
    _, token = create_invitation
    member = Invitations::Accept.call(actor: recipient, token:)
    Members::Remove.new(actor: owner, team:).call(member.id)
    post '/api/v1/invitations/accept', params: { token: }, headers: auth_headers(recipient), as: :json
    expect(response).to have_http_status(:conflict)
    expect(member.reload).to be_removed
  end
end

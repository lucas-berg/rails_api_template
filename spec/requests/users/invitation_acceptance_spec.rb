# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Browser invitation acceptance' do
  it 'keeps the invitation through login and requires an explicit acceptance' do
    owner = create(:user)
    guest = create(:user)
    team = create(:team)
    create(:member, :owner, team:, user: owner)
    invitation = Invitations::Create.new(actor: owner, team:).call(email: guest.email, role: 'member')
    token = MailDelivery.where(kind: 'invitation', team_id: team.id).last.payload.fetch('token')

    get invitation_acceptance_path(token:)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Sign in')
    post user_session_path, params: { user: { email: guest.email, password: guest.password } }
    expect(response).to redirect_to(invitation_acceptance_path)
    get invitation_acceptance_path
    expect(response.body).to include('Accept invitation')
    expect(invitation.reload.accepted_at).to be_nil
    post invitation_acceptance_path
    expect(response).to redirect_to(account_path)
    expect(team.members.find_by!(user: guest)).to be_active
  end

  it 'rejects a different signed-in email' do
    invitation = create(:invitation, token_digest: Digest::SHA256.hexdigest('some-token'))
    sign_in create(:user)
    get invitation_acceptance_path(token: 'some-token')
    expect(response).to have_http_status(:forbidden)
    expect(invitation.reload.accepted_at).to be_nil
  end
end

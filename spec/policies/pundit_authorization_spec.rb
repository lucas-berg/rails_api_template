# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pundit do
  let(:owner) { create(:user) }
  let(:team) { Teams::Create.call(actor: owner, attributes: { name: 'Policy team' }) }

  %w[active suspended].each do |status|
    it "preserves read access for a #{status} team" do
      team.update!(status:)
      expect(described_class.policy!(owner, team)).to be_show
      expect(described_class.policy_scope!(owner, Team)).to include(team)
    end
  end

  it 'excludes a historically deleted team from both record access and the scope' do
    team.update!(status: 'deleted', deleted_at: Time.current)
    expect(described_class.policy!(owner, team)).not_to be_show
    expect(described_class.policy_scope!(owner, Team)).not_to include(team)
  end

  it 'never expands an already limited relation or includes another users team' do
    other_team = create(:team)
    team
    expect(described_class.policy_scope!(owner, Team.where(id: other_team.id))).to be_empty
    expect(described_class.policy_scope!(owner, Team)).to contain_exactly(team)
  end

  it 'removes access after membership removal or account suspension' do
    membership = team.active_members.find_by!(user: owner)
    membership.update!(status: 'removed')
    expect(described_class.policy!(owner, team)).not_to be_show
    expect(described_class.policy_scope!(owner, Team)).to be_empty

    membership.update!(status: 'active')
    owner.suspend!
    expect(described_class.policy!(owner, team)).not_to be_show
    expect(described_class.policy_scope!(owner, Team)).to be_empty
  end

  it 'does not treat a platform administrator as a tenant member' do
    admin = create(:admin_user)
    expect(described_class.policy!(admin, team)).not_to be_show
    expect(described_class.policy_scope!(admin, Team)).to be_empty
  end

  it 'keeps role assignment restrictions distinct from tenant membership' do
    admin = create(:member, team:, role: 'admin').user
    viewer = create(:member, team:, role: 'viewer').user
    owner_member = team.active_members.find_by!(user: owner)
    regular_member = create(:member, team:)

    expect(described_class.policy!(admin, regular_member)).to be_update
    expect(described_class.policy!(admin, owner_member)).not_to be_update
    expect(described_class.policy!(viewer, regular_member)).to be_show
    expect(described_class.policy!(viewer, regular_member)).not_to be_update
    expect(described_class.policy!(admin, team)).not_to be_transfer_ownership
    expect(described_class.policy!(owner, team)).to be_transfer_ownership
  end

  it 'uses the records actual team for tenant authorization' do
    other_member = create(:member)
    expect(described_class.policy!(owner, other_member)).not_to be_show
    expect(described_class.policy!(owner, other_member)).not_to be_destroy
  end

  it 'allows only the verified invitation recipient to accept without a prior membership' do
    recipient = create(:user)
    invitation = Invitations::Create.new(actor: owner, team:).call(email: recipient.email)

    expect(described_class.policy!(recipient, invitation)).to be_accept
    expect(described_class.policy!(owner, invitation)).not_to be_accept
    expect(team.active_members.where(user: recipient)).to be_empty
    recipient.update!(confirmed_at: nil)
    expect(described_class.policy!(recipient, invitation)).not_to be_accept
  end

  it 'allows team administrators to invite regular members but not other administrators' do
    admin = create(:member, team:, role: 'admin').user
    invitation = team.invitations.build(role: 'member')
    expect(described_class.policy!(admin, invitation)).to be_create
    invitation.role = 'admin'
    expect(described_class.policy!(admin, invitation)).not_to be_create
    expect(described_class.policy!(owner, invitation)).to be_create
  end

  it 'restricts personal sessions and preferences to their owner' do
    outsider = create(:user)
    headers = auth_headers(owner)
    expect(headers).to have_key('Authorization')
    session = owner.auth_sessions.last
    preference = NotificationPreference.new(user: owner)

    expect(described_class.policy!(owner, session)).to be_destroy
    expect(described_class.policy!(outsider, session)).not_to be_destroy
    expect(described_class.policy_scope!(outsider, AuthSession)).not_to include(session)
    expect(described_class.policy!(outsider, preference)).not_to be_update
  end

  it 'keeps support read-only and gives privileged operations only to platform super administrators' do
    support = create(:admin_user, :support)
    super_admin = create(:admin_user)
    support_policy = described_class.policy!(support, [:admin, owner])

    expect(support_policy).to be_index
    expect(support_policy).to be_show
    expect(support_policy).not_to be_suspend
    expect(support_policy).not_to be_destroy
    expect(described_class.policy!(super_admin, [:admin, owner])).to be_suspend
    expect(described_class.policy!(support, [:admin, AdminUser])).not_to be_create
    expect(described_class.policy!(super_admin, [:admin, AdminUser])).to be_create
    expect(described_class.policy!(support, %i[admin dashboard])).not_to be_manage_tools
    expect(described_class.policy!(super_admin, %i[admin dashboard])).to be_manage_tools
    expect(described_class.policy!(owner, [:admin, owner])).not_to be_show
    expect(described_class.policy_scope!(owner, [:admin, User])).to be_empty
  end

  it 'denies unimplemented operations instead of falling back to platform read access' do
    admin = create(:admin_user)
    expect { described_class.authorize(admin, [:admin, team], :destroy?) }.to raise_error(Pundit::NotAuthorizedError)
    expect { described_class.authorize(admin, [:admin, MailDelivery], :update?) }.to raise_error(Pundit::NotAuthorizedError)
    expect { described_class.policy!(admin, [:admin, Object.new]) }.to raise_error(Pundit::NotDefinedError)
  end
end

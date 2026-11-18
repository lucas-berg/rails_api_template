# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Teams::Create do
  let(:owner) { create(:user) }
  let(:user) { create(:user) }
  let(:team) { described_class.call(actor: owner, attributes: { name: 'Protected team' }) }

  it 'rolls the team and first owner back when recording its audit event fails' do
    user
    allow(AuditEvent).to receive(:record!).and_raise(ActiveRecord::RecordInvalid)
    expect {
      expect {
        described_class.call(actor: user, attributes: { name: 'Incomplete team' })
      }.to raise_error(ActiveRecord::RecordInvalid)
    }.not_to change(Team, :count)
    expect(Member.where(user:)).to be_empty
  end

  it 'rechecks an actor suspended after it was loaded before a team update' do
    original_name = team.name
    User.find(owner.id).suspend!
    expect {
      Teams::Update.new(actor: owner, team:).call(name: 'Unauthorized rename')
    }.to raise_error(Pundit::NotAuthorizedError)
    expect(team.reload.name).to eq(original_name)
  end

  it 'rechecks a stale suspended account before creating a team' do
    User.find(user.id).suspend!
    expect {
      described_class.call(actor: user, attributes: { name: 'Unauthorized team' })
    }.to raise_error(Pundit::NotAuthorizedError)
    expect(Member.where(user:, role: 'owner')).to be_empty
  end

  it 'rechecks a stale suspended account before accepting an invitation' do
    invitation = Invitations::Create.new(actor: owner, team:).call(email: user.email)
    token = MailDelivery.where(kind: 'invitation', team_id: team.id).last.payload.fetch('token')
    User.find(user.id).suspend!

    expect { Invitations::Accept.call(actor: user, token:) }.to raise_error(Pundit::NotAuthorizedError)
    expect(invitation.reload.accepted_at).to be_nil
    expect(team.members.where(user:)).to be_empty
  end

  it 'keeps the existing owner when the proposed owner account has been suspended' do
    member = create(:member, user:, team:)
    user.suspend!

    expect {
      Members::TransferOwnership.new(actor: owner, team:).call(member.id)
    }.to raise_error(Collaboration::Conflict, /active account/)
    expect(member.reload).to be_member
    expect(team.active_members.owner.sole.user).to eq(owner)
  end

  it 'does not restore a historically deleted account through a stale instance or a direct status update' do
    stale = User.find(user.id)
    user.update!(deleted_at: Time.current, status: 'suspended')
    expect { stale.restore! }.to raise_error(ActiveRecord::RecordInvalid, /deleted account/)
    expect { user.update!(status: 'active') }.to raise_error(ActiveRecord::RecordInvalid, /deleted account/)
    expect(user.reload).to be_suspended
    expect(user).not_to be_active_for_authentication
  end

  it 'does not reactivate a historically deleted team through a direct status update' do
    team.update!(status: 'deleted', deleted_at: Time.current)
    expect { team.update!(status: 'active') }.to raise_error(ActiveRecord::RecordInvalid, /deleted team/)
    expect(team.reload).to be_deleted
  end
end

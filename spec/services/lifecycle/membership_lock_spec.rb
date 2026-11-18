# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lifecycle::MembershipLock do
  let(:owner) { create(:user) }
  let(:user) { create(:user) }
  let(:team) { Teams::Create.call(actor: owner, attributes: { name: 'Lifecycle team' }) }

  def schedule_deletion
    Deletions::Request.call(actor: user, subject: user, password: user.password)
  end

  it 'blocks creating a team while account deletion is pending' do
    schedule_deletion
    expect {
      Teams::Create.call(actor: user, attributes: { name: 'New ownership' })
    }.to raise_error(Collaboration::Conflict, /Cancel account deletion/)
    expect(Member.where(user:, role: 'owner')).to be_empty
  end

  it 'blocks accepting an invitation while account deletion is pending' do
    invitation = Invitations::Create.new(actor: owner, team:).call(email: user.email)
    token = MailDelivery.where(kind: 'invitation', team_id: team.id).last.payload.fetch('token')
    schedule_deletion
    expect { Invitations::Accept.call(actor: user, token:) }
      .to raise_error(Collaboration::Conflict, /Cancel account deletion/)
    expect(invitation.reload.accepted_at).to be_nil
  end

  it 'blocks transferring ownership to an account pending deletion' do
    member = create(:member, user:, team:)
    schedule_deletion
    expect {
      Members::TransferOwnership.new(actor: owner, team:).call(member.id)
    }.to raise_error(Collaboration::Conflict, /Cancel account deletion/)
    expect(member.reload).to be_member
  end

  it 'rechecks an actor whose account was suspended after it was loaded' do
    original_name = team.name
    User.find(owner.id).suspend!
    expect {
      Teams::Update.new(actor: owner, team:).call(name: 'Unauthorized rename')
    }.to raise_error(Authorization::Forbidden)
    expect(team.reload.name).to eq(original_name)
  end

  it 'rechecks a stale suspended account before creating a team' do
    user
    User.find(user.id).suspend!
    expect {
      Teams::Create.call(actor: user, attributes: { name: 'Unauthorized team' })
    }.to raise_error(Authorization::Forbidden)
  end

  it 'does not restore a tombstoned account through a stale instance or direct status updates' do
    stale = User.find(user.id)
    user.update!(deleted_at: Time.current, status: 'suspended')
    expect { stale.restore! }.to raise_error(ActiveRecord::RecordInvalid, /deleted account/)
    expect { user.update!(status: 'active') }.to raise_error(ActiveRecord::RecordInvalid, /deleted account/)
    expect(user.reload).to be_suspended
    expect(user).not_to be_active_for_authentication
  end

  it 'does not restore an account whose cleanup began but failed before anonymization' do
    deletion = schedule_deletion
    user.suspend!
    deletion.update!(status: 'failed', stage: 'ledger')
    expect(user.deleted_at).to be_nil
    expect(user).not_to be_restorable
    expect { user.restore! }.to raise_error(ActiveRecord::RecordInvalid, /being deleted/)
    expect { user.update!(status: 'active') }.to raise_error(ActiveRecord::RecordInvalid, /being deleted/)
    expect(user.reload).to be_suspended
  end
end

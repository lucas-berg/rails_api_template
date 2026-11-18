# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Collaboration::Operation do
  let(:owner) { create(:user) }
  let(:team) { Teams::Create.call(actor: owner, attributes: { name: 'Service team' }) }

  it 'rolls back a team update if audit persistence fails' do
    team
    allow(AuditEvent).to receive(:record!).and_raise(ActiveRecord::RecordInvalid)
    expect {
      Teams::Update.new(actor: owner, team:).call(name: 'Uncommitted')
    }.to raise_error(ActiveRecord::RecordInvalid)
    expect(team.reload.name).to eq('Service team')
  end

  it 'rolls back an invitation if its mail intent cannot be persisted' do
    team
    allow(MailDelivery).to receive(:enqueue_invitation).and_raise(ActiveRecord::RecordInvalid)
    expect {
      Invitations::Create.new(actor: owner, team:).call(email: 'mail@example.com')
    }.to raise_error(ActiveRecord::RecordInvalid)
    expect(team.invitations.count).to eq(0)
    expect(team.audit_events.where(action: 'invitation.created').count).to eq(0)
  end

  it 'denies unknown authorization actions and resources' do
    expect { Pundit.authorize(owner, team, :destroy?) }.to raise_error(Pundit::NotAuthorizedError)
    expect { Pundit.policy!(owner, Object.new) }.to raise_error(Pundit::NotDefinedError)
    expect { Pundit.authorize(nil, team, :show?) }.to raise_error(Pundit::NotAuthorizedError)
  end

  it 'does not permit a service caller to operate on a foreign team member' do
    outsider = create(:member)
    expect {
      Members::Remove.new(actor: owner, team:).call(outsider.id)
    }.to raise_error(ActiveRecord::RecordNotFound)
    expect(outsider.reload).to be_active
  end

  it 'enforces member uniqueness at the database layer' do
    existing = team.members.find_by!(user: owner)
    duplicate = existing.dup
    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'does not allow an unconfirmed email to accept an invitation through the service' do
    user = create(:user, confirmed_at: nil)
    Invitations::Create.new(actor: owner, team:).call(email: user.email)
    token = MailDelivery.where(kind: 'invitation').last.payload.fetch('token')
    expect { Invitations::Accept.call(actor: user, token:) }.to raise_error(Pundit::NotAuthorizedError)
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MailDeliveryMessage do
  let(:owner) { create(:user) }
  let(:team) { Team.create!(name: 'Research') }
  let(:token) { SecureRandom.urlsafe_base64(32) }
  let(:invitation) do
    team.members.create!(user: owner, role: 'owner')
    team.invitations.create!(normalized_email: 'invitee@example.com', invited_by: owner,
                             role: 'member', token_digest: Digest::SHA256.hexdigest(token),
                             expires_at: 7.days.from_now)
  end
  let(:delivery) { MailDelivery.enqueue_invitation(invitation, token) }

  it 'builds a multipart invitation with the configured acceptance link' do
    message = described_class.new(delivery).build
    expect(message.to).to eq(['invitee@example.com'])
    expect(message.html_part.body.decoded).to include('/invitations/accept?token=', token)
    expect(message.text_part.body.decoded).to include(team.name)
  end

  it 'deduplicates an invitation token before delivery' do
    delivery
    expect { MailDelivery.enqueue_invitation(invitation, token) }.not_to change(MailDelivery, :count)
  end

  it 'does not send a revoked invitation' do
    delivery
    invitation.update!(revoked_at: Time.current)
    expect(described_class.new(delivery).build).to be_nil
  end

  it 'does not send an accepted invitation' do
    delivery
    invitation.update!(accepted_at: Time.current)
    expect(described_class.new(delivery).build).to be_nil
  end

  it 'does not send a superseded token' do
    delivery
    invitation.update!(token_digest: Digest::SHA256.hexdigest('replacement-token'))
    expect(described_class.new(delivery).build).to be_nil
  end

  it 'does not send expired invitations' do
    delivery
    travel 8.days do
      expect(described_class.new(delivery).build).to be_nil
    end
  end

  it 'does not send invitations for suspended teams' do
    delivery
    team.update!(status: 'suspended')
    expect(described_class.new(delivery).build).to be_nil
  end

  it 'does not send invitations after the inviter is removed' do
    delivery
    team.members.find_by!(user: owner).update!(status: 'removed')
    expect(described_class.new(delivery).build).to be_nil
  end

  it 'does not send invitations after the inviter loses permission to grant the role' do
    delivery
    invitation.update!(role: 'admin')
    team.members.find_by!(user: owner).update!(role: 'admin')
    expect(described_class.new(delivery).build).to be_nil
  end

  it 'does not send invitations from suspended accounts' do
    delivery
    owner.suspend!
    expect(described_class.new(delivery).build).to be_nil
  end
end

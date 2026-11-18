# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocumentPolicy do
  let(:document) { create(:document) }
  let(:team) { document.team }

  it 'allows all active team members to read but keeps viewers read-only' do
    viewer = create(:member, :viewer, team:)
    policy = described_class.new(viewer.user, document, team)
    expect(policy.allowed?(:download)).to be(true)
    expect(policy.allowed?(:create)).to be(false)
    expect(policy.allowed?(:remove)).to be(false)
  end

  it 'allows completion and avatar assignment only to the uploader' do
    admin = create(:member, :admin, team:)
    policy = described_class.new(admin.user, document, team)
    expect(policy.allowed?(:remove)).to be(true)
    expect(policy.allowed?(:complete)).to be(false)
    expect(policy.allowed?(:avatar)).to be(false)
  end

  it 'hides cross-team resources and denies unknown actions' do
    other = create(:team)
    create(:member, :owner, team: other, user: document.uploader)
    expect(described_class.new(document.uploader, document, other).allowed?(:download)).to be(false)
    expect(described_class.new(document.uploader, document, team).allowed?(:publish)).to be(false)
  end

  it 'rejects suspended users and removed memberships' do
    member = team.members.find_by!(user: document.uploader)
    member.update!(status: 'removed')
    expect(described_class.new(document.uploader, document, team).allowed?(:download)).to be(false)
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Team dashboard and onboarding' do
  let(:user) { create(:user, preferences: { 'locale' => 'zh-CN' }) }
  let(:team) { create(:team, timezone: 'Asia/Shanghai') }

  it 'returns tenant-scoped counts and effective personal preferences' do
    create(:member, :owner, team:, user:)
    create(:member)
    create(:invitation, team:)
    get "/api/v1/teams/#{team.id}/dashboard", headers: auth_headers(user)
    expect(response).to have_http_status(:ok)
    expect(json.dig('data', 'counts')).to include('members' => 1, 'files' => 0, 'pending_invitations' => 1)
    expect(json.dig('data', 'preferences')).to eq('locale' => 'zh-CN', 'timezone' => 'Asia/Shanghai')
  end

  it 'gives viewers only actions they may perform' do
    create(:member, :viewer, team:, user:)
    get "/api/v1/teams/#{team.id}/onboarding", headers: auth_headers(user)
    expect(json.dig('data', 'steps').pluck('key')).to eq(%w[verify_email join_team])
  end

  it 'derives invitation progress from team data' do
    create(:member, :owner, team:, user:)
    get "/api/v1/teams/#{team.id}/onboarding", headers: auth_headers(user)
    expect(json.dig('data', 'steps').last).to include('key' => 'invite_teammate', 'completed' => false)
  end

  it 'rejects another team even with a valid user token' do
    get "/api/v1/teams/#{team.id}/dashboard", headers: auth_headers(user)
    expect(response).to have_http_status(:not_found)
  end
end

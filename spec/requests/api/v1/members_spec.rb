# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Members API', openapi: { security: [{ 'BearerAuth' => [] }] } do
  let(:owner) { create(:user) }
  let(:team) { Teams::Create.call(actor: owner, attributes: { name: 'Members' }) }
  let(:headers) { auth_headers(owner) }

  it 'lists only active team members without credentials' do
    create(:member, team:, status: 'removed')
    get "/api/v1/teams/#{team.id}/members", headers: headers
    expect(response).to have_http_status(:ok)
    expect(json[:data].pluck(:user_id)).to eq([owner.id])
    expect(json[:data].first[:user]).not_to have_key(:encrypted_password)
  end

  %i[patch put].each do |method|
    it "allows an owner to change an ordinary member role using #{method.upcase}" do
      member = create(:member, team:)
      public_send(method, "/api/v1/teams/#{team.id}/members/#{member.id}",
                  params: { member: { role: 'admin' } }, headers:, as: :json)
      expect(response).to have_http_status(:ok)
      expect(member.reload).to be_admin
    end
  end

  it 'removes member access immediately using an existing JWT',
     openapi: { request_pattern: 'DELETE /api/v1/teams/{team_id}/members/{id}' } do
    member = create(:member, team:)
    member_headers = auth_headers(member.user)
    delete "/api/v1/teams/#{team.id}/members/#{member.id}", headers: headers
    expect(response).to have_http_status(:no_content)
    get "/api/v1/teams/#{team.id}", headers: member_headers
    expect(response).to have_http_status(:not_found)
  end

  %w[owner other_admin self].each do |target_role|
    it "prevents an admin from modifying #{target_role}" do
      admin = create(:member, :admin, team:)
      target = case target_role
               when 'owner' then team.active_members.find_by!(user: owner)
               when 'other_admin' then create(:member, :admin, team:)
               else admin
               end
      patch "/api/v1/teams/#{team.id}/members/#{target.id}", params: { member: { role: 'admin' } },
                                                             headers: auth_headers(admin.user), as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  it 'allows admins to manage ordinary roles but cannot grant admin' do
    admin = create(:member, :admin, team:)
    member = create(:member, team:)
    patch "/api/v1/teams/#{team.id}/members/#{member.id}", params: { member: { role: 'viewer' } },
                                                           headers: auth_headers(admin.user), as: :json
    expect(response).to have_http_status(:ok)

    patch "/api/v1/teams/#{team.id}/members/#{member.id}", params: { member: { role: 'admin' } },
                                                           headers: auth_headers(admin.user), as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it 'prevents removing or demoting the last owner' do
    member = team.active_members.find_by!(user: owner)
    delete "/api/v1/teams/#{team.id}/members/#{member.id}", headers: headers
    expect(response).to have_http_status(:conflict)
    patch "/api/v1/teams/#{team.id}/members/#{member.id}", params: { member: { role: 'admin' } }, headers:, as: :json
    expect(response).to have_http_status(:conflict)
    expect(member.reload).to be_owner
  end

  it 'transfers ownership atomically and demotes the previous owner' do
    member = create(:member, team:)
    post "/api/v1/teams/#{team.id}/ownership_transfer", params: { member_id: member.id }, headers:, as: :json
    expect(response).to have_http_status(:ok)
    expect(member.reload).to be_owner
    expect(team.active_members.find_by!(user: owner)).to be_admin
    expect(team.active_members.owner.count).to eq(1)
    expect(team.audit_events.last.action).to eq('team.ownership_transferred')
  end

  it 'rejects cross-team member IDs' do
    outsider = create(:member)
    patch "/api/v1/teams/#{team.id}/members/#{outsider.id}", params: { member: { role: 'admin' } }, headers:, as: :json
    expect(response).to have_http_status(:not_found)
  end
end

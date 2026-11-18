# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Notifications API', openapi: { security: [{ 'BearerAuth' => [] }] } do
  let(:user) { create(:user) }
  let(:team) { create(:team) }
  let!(:member) { create(:member, user:, team:) }
  let(:headers) { auth_headers(user) }

  def publish_activity(recipient = user)
    Notifications::Publish.call(user: recipient, team:, kind: 'invitation_accepted',
                                event_key: "invite-#{recipient.id}")
  end

  it 'lists only the current user notifications in the requested team' do
    own = publish_activity
    other = create(:user)
    create(:member, user: other, team:)
    publish_activity(other)
    get "/api/v1/teams/#{team.id}/notifications", headers: headers

    expect(response).to have_http_status(:ok)
    expect(json.fetch(:data).pluck(:id)).to eq([own.id])
    expect(json.fetch(:meta).fetch(:total)).to eq(1)
  end

  it 'marks a notification read idempotently' do
    notification = publish_activity
    post "/api/v1/teams/#{team.id}/notifications/#{notification.id}/read", headers: headers
    expect(response).to have_http_status(:ok)
    timestamp = notification.reload.read_at
    travel 1.hour do
      post "/api/v1/teams/#{team.id}/notifications/#{notification.id}/read", headers: headers
      expect(response).to have_http_status(:ok)
      expect(notification.reload.read_at).to eq(timestamp)
    end
  end

  it 'rejects another recipient notification even inside the same team' do
    other = create(:user)
    create(:member, user: other, team:)
    notification = publish_activity(other)
    post "/api/v1/teams/#{team.id}/notifications/#{notification.id}/read", headers: headers
    expect(response).to have_http_status(:not_found)
    expect(notification.reload.read_at).to be_nil
  end

  it 'rejects a cross-team notification ID' do
    notification = publish_activity
    other_team = create(:team)
    create(:member, user:, team: other_team)
    post "/api/v1/teams/#{other_team.id}/notifications/#{notification.id}/read", headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it 'revokes notification access when the user leaves the team' do
    publish_activity
    signed_headers = headers
    member.update!(status: 'removed')
    get "/api/v1/teams/#{team.id}/notifications", headers: signed_headers
    expect(response).to have_http_status(:not_found)
  end

  it 'lists personal security notifications separately from team activity' do
    publish_activity
    security = Notifications::Publish.call(user:, kind: 'password_changed', event_key: 'password-1')
    get '/api/v1/security_notifications', headers: headers
    expect(response).to have_http_status(:ok)
    expect(json.fetch(:data).pluck(:id)).to eq([security.id])

    post "/api/v1/security_notifications/#{security.id}/read", headers: headers
    expect(response).to have_http_status(:ok)
    expect(security.reload.read_at).to be_present
  end

  it 'requires authentication' do
    get '/api/v1/security_notifications'
    expect(response).to have_http_status(:unauthorized)
  end
end

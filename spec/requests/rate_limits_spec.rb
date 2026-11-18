# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rate limits' do
  around do |example|
    previous_store = Rack::Attack.cache.store
    previous_enabled = Rack::Attack.enabled
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.enabled = true
    example.run
  ensure
    Rack::Attack.cache.store = previous_store
    Rack::Attack.enabled = previous_enabled
  end

  it 'limits JSON logins by IP and supplies a retry delay' do
    10.times do
      post '/users/sign_in', params: { user: { email: 'absent@example.com', password: 'incorrect' } }, as: :json
      Prosopite.finish
      Prosopite.scan
    end
    expect(response).to have_http_status(:unauthorized)
    post '/users/sign_in', params: { user: { email: 'absent@example.com', password: 'incorrect' } }, as: :json
    expect(response).to have_http_status(:too_many_requests)
    expect(response.headers['Retry-After'].to_i).to be_between(1, 60)
  end

  it 'normalizes recovery emails and counts JSON and form submissions together' do
    3.times do
      post '/users/password', params: { user: { email: 'Person@example.com' } }, as: :json
      Prosopite.finish
      Prosopite.scan
    end
    post '/users/password', params: { user: { email: ' person@EXAMPLE.com ' } }
    expect(response).to have_http_status(:too_many_requests)
  end

  it 'enforces invitation limits after authorization per team' do
    owner = create(:user)
    team = create(:team)
    create(:member, :owner, team:, user: owner)
    headers = auth_headers(owner)
    30.times do |index|
      post "/api/v1/teams/#{team.id}/invitations", params: { invitation: { email: "invite#{index}@example.com" } },
                                                   headers:, as: :json
      Prosopite.finish
      Prosopite.scan
    end
    expect(response).to have_http_status(:created)
    post "/api/v1/teams/#{team.id}/invitations", params: { invitation: { email: 'overflow@example.com' } },
                                                 headers:, as: :json
    expect(response).to have_http_status(:too_many_requests)
    expect(response.headers['Retry-After'].to_i).to be_positive
  end

  it 'shares Redis counters across independent cache clients' do
    first = RateLimits.store
    second = RateLimits.store
    key = "spec:#{SecureRandom.uuid}"
    expect(first.increment(key, 1, expires_in: 60)).to eq(1)
    expect(second.increment(key, 1, expires_in: 60)).to eq(2)
  ensure
    first&.delete(key)
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Request and background job correlation' do
  let!(:user) { create(:user, :unconfirmed) }

  before { clear_enqueued_jobs }

  it 'preserves the JSON confirmation request ID in its asynchronously queued mail' do
    post '/users/confirmation', params: { user: { email: user.email } },
                                headers: { 'X-Request-ID' => 'json-confirmation-request' }, as: :json
    expect(response).to have_http_status(:created)
    delivery = enqueued_jobs.find { |job| job[:job] == SendMailDeliveryJob }
    expect(delivery.fetch('source_request_id')).to eq('json-confirmation-request')
    expect(Current.attributes.values).to all(be_nil)
  end

  it 'preserves the browser form request ID through transaction commit and resets the next request' do
    post '/users/confirmation', params: { user: { email: user.email } },
                                headers: { 'X-Request-ID' => 'browser-confirmation-request' }
    expect(response).to have_http_status(:redirect)
    delivery = enqueued_jobs.find { |job| job[:job] == SendMailDeliveryJob }
    expect(delivery.fetch('source_request_id')).to eq('browser-confirmation-request')
    expect(Current.attributes.values).to all(be_nil)

    get '/api/v1/status', headers: { 'X-Request-ID' => 'next-request' }
    expect(response.headers['X-Request-ID']).to eq('next-request')
    expect(Current.attributes.values).to all(be_nil)
  end

  it 'keeps authorized team correlation for the request log after Current has been reset' do
    member = create(:member)
    get "/api/v1/teams/#{member.team_id}", headers: auth_headers(member.user).merge('X-Request-ID' => 'team-request')
    expect(response).to have_http_status(:ok)
    expect(Current.attributes.values).to all(be_nil)
    expect(request.env.fetch('saas.context')).to eq(user_id: member.user_id, team_id: member.team_id)
    payload = Rails.application.config.lograge.custom_payload_method.call(request.controller_instance)
    expect(payload).to include(current_user_id: member.user_id, team_id: member.team_id, request_id: 'team-request')

    get "/api/v1/teams/#{member.team_id}", headers: auth_headers(create(:user))
    expect(response).to have_http_status(:not_found)
    expect(request.env.fetch('saas.context').fetch(:team_id)).to be_nil
  end
end

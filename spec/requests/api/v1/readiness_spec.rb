# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Readiness API' do
  it 'checks the database and shared rate limit store' do
    get '/api/v1/ready'
    expect(response).to have_http_status(:ok)
    expect(json).to eq('ready' => true)
  end

  it 'reports unavailable dependencies without exposing connection details' do
    allow(RateLimits).to receive(:store).and_raise(Redis::CannotConnectError, 'secret internal address')
    get '/api/v1/ready'
    expect(response).to have_http_status(:service_unavailable)
    expect(json).to eq('ready' => false)
  end
end

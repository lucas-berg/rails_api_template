# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Notification preferences', openapi: { security: [{ 'BearerAuth' => [] }] } do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  it 'returns defaults without creating a record' do
    expect {
      get '/api/v1/notification_preferences', headers: headers
    }.not_to change(NotificationPreference, :count)
    expect(response).to have_http_status(:ok)
    expect(json.fetch(:data)).to include(activity_in_app: true, activity_email: false,
                                         security_in_app: true, security_email: true)
  end

  it 'updates optional channels for only the authenticated user' do
    other = create(:user)
    NotificationPreference.create!(user: other)
    patch '/api/v1/notification_preferences', headers: headers,
                                              params: { notification_preferences: { activity_in_app: false,
                                                                                    activity_email: true } }, as: :json
    expect(response).to have_http_status(:ok)
    expect(NotificationPreference.find_by!(user:)).to have_attributes(activity_in_app: false, activity_email: true)
    expect(NotificationPreference.find_by!(user: other).activity_email).to be(false)
  end

  it 'rejects disabling compulsory security notifications' do
    patch '/api/v1/notification_preferences', headers: headers,
                                              params: { notification_preferences: { security_email: false } }, as: :json
    expect(response).to have_http_status(:bad_request)
  end

  it 'rejects nonboolean values' do
    preferences = { activity_email: 'false' }
    patch '/api/v1/notification_preferences', headers: headers,
                                              params: { notification_preferences: preferences }, as: :json
    expect(response).to have_http_status(:bad_request)
  end

  it 'rejects recipient injection' do
    patch '/api/v1/notification_preferences', headers: headers,
                                              params: { notification_preferences: { user_id: 123 } }, as: :json
    expect(response).to have_http_status(:bad_request)
  end

  it 'updates optional notification channels through the PUT alias' do
    put '/api/v1/notification_preferences', headers: headers,
                                            params: { notification_preferences: { activity_email: true } }, as: :json
    expect(response).to have_http_status(:ok)
    expect(NotificationPreference.for(user).activity_email).to be(true)
  end
end

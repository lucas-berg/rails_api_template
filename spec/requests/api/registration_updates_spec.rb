# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'JSON registration maintenance', openapi: { security: [{ 'BearerAuth' => [] }] } do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  %i[patch put].each do |method|
    it "changes the account password through #{method.upcase} and revokes the previous JWT" do
      old_headers = headers
      attributes = { current_password: user.password, password: 'Changed-through-registration!',
                     password_confirmation: 'Changed-through-registration!' }
      public_send(method, user_registration_path, headers: old_headers, params: { user: attributes }, as: :json)
      expect(response).to have_http_status(:no_content)
      expect(user.reload.valid_password?('Changed-through-registration!')).to be(true)
      expect(user.auth_sessions.where(revoked_at: nil)).to be_empty
    end
  end

  it 'schedules account deletion without immediately deleting the user' do
    signed_headers = headers
    expect {
      delete user_registration_path, headers: signed_headers, params: { current_password: user.password }, as: :json
    }.not_to change(User, :count)
    expect(response).to have_http_status(:accepted)
    expect(json[:data]).to include(status: 'pending', stage: 'requested', subject_type: 'User')
    expect(response.headers['Location']).to eq("/api/v1/deletion_requests/#{json[:data][:id]}")
  end
end

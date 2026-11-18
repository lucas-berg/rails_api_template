# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Administrator authentication' do
  it 'renders the dedicated login and recovery forms without ActiveAdmin assets' do
    get new_admin_user_session_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('administrator account', 'admin_user[email]', 'admin_user[password]')
    expect(response.body).not_to include('active_admin', 'jquery')
    get new_admin_user_password_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Send reset link')
  end

  it 'signs in with an administrator cookie and signs out through the protected form' do
    admin = create(:admin_user)
    post admin_user_session_path, params: { admin_user: { email: admin.email, password: admin.password } }
    expect(response).to redirect_to(admin_root_path)
    get admin_root_path
    expect(response).to have_http_status(:ok)
    delete destroy_admin_user_session_path
    expect(response).to redirect_to(new_admin_user_session_path)
  end

  it 'keeps the complete password recovery flow available' do
    admin = create(:admin_user)
    post admin_user_password_path, params: { admin_user: { email: admin.email } }
    expect(response).to redirect_to(new_admin_user_session_path)
    token = admin.send_reset_password_instructions
    get edit_admin_user_password_path, params: { reset_password_token: token }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Confirm new password')
    put admin_user_password_path, params: { admin_user: { reset_password_token: token,
                                                          password: 'Recovered-admin-password!',
                                                          password_confirmation: 'Recovered-admin-password!' } }
    expect(response).to have_http_status(:redirect)
    expect(admin.reload).to be_valid_password('Recovered-admin-password!')
  end

  context 'with CSRF protection enabled' do
    around do |example|
      previous = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      example.run
    ensure
      ActionController::Base.allow_forgery_protection = previous
    end

    it 'rejects sign-in and privileged writes without a form token' do
      admin = create(:admin_user)
      post admin_user_session_path, params: { admin_user: { email: admin.email, password: admin.password } }
      expect(response).to have_http_status(:unprocessable_content)
      sign_in admin
      team = create(:team)
      post "/admin/teams/#{team.id}/suspend", params: { reason: 'Forged request' }
      expect(response).to have_http_status(:unprocessable_content)
      expect(team.reload).to be_active
    end
  end
end

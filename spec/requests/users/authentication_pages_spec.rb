# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User authentication pages' do
  it 'renders the Turbo-enabled sign-in page' do
    get new_user_session_path

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.at_css('turbo-frame#user_authentication')).to be_present
    expect(response.body).to include('data-controller="form"')
  end

  it 'renders the Turbo-enabled registration page' do
    get new_user_registration_path

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.at_css('turbo-frame#user_authentication')).to be_present
    expect(response.body).to include('data-controller="password"')
  end

  it 'protects the account page' do
    get account_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it 'signs in and redirects to the account page' do
    user = create(:user, password: 'Password123!')

    post user_session_path, params: { user: { email: user.email, password: 'Password123!' } }

    expect(response).to redirect_to(account_path)
    expect(response.headers['Authorization']).to be_nil
  end

  it 'registers and redirects to the account page' do
    post user_registration_path,
         params: { user: { email: 'new-user@example.com', password: 'Password123!',
                           password_confirmation: 'Password123!' } }

    expect(response).to redirect_to(account_path)
  end

  context 'with forgery protection enabled' do
    around do |example|
      previous = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      example.run
    ensure
      ActionController::Base.allow_forgery_protection = previous
    end

    it 'requires the HTML sign-in form token' do
      user = create(:user)
      post user_session_path, params: { user: { email: user.email, password: user.password } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'accepts a JSON sign-in without a browser session' do
      user = create(:user)
      post user_session_path, params: { user: { email: user.email, password: user.password } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.headers['Set-Cookie']).to be_nil
    end
  end
end

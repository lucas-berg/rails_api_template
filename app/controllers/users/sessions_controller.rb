# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    prepend_before_action(only: :destroy, if: -> { request.format.json? }) { authenticate_user!(force: true) }
    after_action :omit_browser_token, only: :create, unless: -> { request.format.json? }

    def create
      super do |user|
        register_api_session(user) if request.format.json?
      end
    rescue AuthSession::InvalidCredentials
      request.env.delete(Warden::JWTAuth::Hooks::PREPARED_TOKEN_ENV_KEY)
      sign_out(:user)
      render json: { error: 'Credentials have changed. Please sign in again.' }, status: :unauthorized
    end

    protected

    def after_sign_in_path_for(_resource)
      session[:pending_invitation_token].present? ? invitation_acceptance_path : account_path
    end

    private

    def register_api_session(user)
      token = request.env.fetch(Warden::JWTAuth::Hooks::PREPARED_TOKEN_ENV_KEY)
      context = { user_agent: request.user_agent, ip_address: request.remote_ip }
      AuthSession.register!(user, Warden::JWTAuth::TokenDecoder.new.call(token), context:)
    end

    def omit_browser_token
      # devise-jwt matches the path even when Rails negotiates HTML on the shared sign-in URL.
      request.env.delete(Warden::JWTAuth::Hooks::PREPARED_TOKEN_ENV_KEY)
    end
  end
end

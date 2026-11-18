# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    prepend_before_action(only: :destroy, if: -> { request.format.json? }) { authenticate_user!(force: true) }
    after_action :omit_browser_token, only: :create, unless: -> { request.format.json? }

    protected

    def after_sign_in_path_for(_resource)
      account_path
    end

    private

    def omit_browser_token
      # devise-jwt matches the path even when Rails negotiates HTML on the shared sign-in URL.
      request.env.delete(Warden::JWTAuth::Hooks::PREPARED_TOKEN_ENV_KEY)
    end
  end
end

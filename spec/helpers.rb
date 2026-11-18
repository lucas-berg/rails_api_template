# frozen_string_literal: true

require 'devise/jwt/test_helpers'

module Helpers
  # Helper method to parse a response
  #
  # @return [Hash]
  def json
    JSON.parse(response.body).with_indifferent_access
  end

  def auth_headers(user)
    headers = Devise::JWT::TestHelpers.auth_headers({}, user)
    token = headers.fetch('Authorization').delete_prefix('Bearer ')
    AuthSession.register!(user, Warden::JWTAuth::TokenDecoder.new.call(token))
    headers
  end
end

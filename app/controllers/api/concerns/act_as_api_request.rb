# frozen_string_literal: true

module API
  module Concerns
    module ActAsAPIRequest
      private

      def use_stateless_session
        ActionController::RequestForgeryProtection::ProtectionMethods::NullSession.new(self).handle_unverified_request
      end
    end
  end
end

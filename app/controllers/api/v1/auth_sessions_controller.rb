# frozen_string_literal: true

module API
  module V1
    class AuthSessionsController < SaasController
      def index
        render_collection(current_user.auth_sessions.active) do |session|
          session.as_json(only: %i[id created_at expires_at last_used_at])
        end
      end

      def destroy
        current_user.auth_sessions.find(params.expect(:id)).revoke!
        head :no_content
      end
    end
  end
end

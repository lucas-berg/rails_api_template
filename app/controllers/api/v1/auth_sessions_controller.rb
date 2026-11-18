# frozen_string_literal: true

module API
  module V1
    class AuthSessionsController < SaasController
      def index
        render_collection(policy_scope(AuthSession).active) do |session|
          session.as_json(only: %i[id created_at expires_at last_used_at user_agent ip_address])
        end
      end

      def destroy
        session = policy_scope(AuthSession).find(params.expect(:id))
        authorize session, :destroy?
        session.revoke!
        head :no_content
      end
    end
  end
end

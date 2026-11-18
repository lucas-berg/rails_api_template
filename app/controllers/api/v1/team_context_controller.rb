# frozen_string_literal: true

module API
  module V1
    class TeamContextController < SaasController
      before_action :load_team

      private

      def load_team
        @team = Authorization.team_scope(current_user).find(params.expect(:team_id))
        Current.team = @team
      end

      def operation_options
        { actor: current_user, team: @team, request_id: request.request_id }
      end
    end
  end
end

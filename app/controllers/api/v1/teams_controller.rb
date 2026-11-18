# frozen_string_literal: true

module API
  module V1
    class TeamsController < SaasController
      before_action :load_team, only: %i[show update]

      def index
        render_collection(policy_scope(Team)) { |team| SaasPresenter.team(team) }
      end

      def show
        authorize @team, :show?
        render_data(SaasPresenter.team(@team))
      end

      def create
        authorize Team, :create?
        team = Teams::Create.call(actor: current_user, attributes: team_params, request_id: request.request_id)
        render_data(SaasPresenter.team(team), status: :created)
      end

      def update
        authorize @team, :update?
        Teams::Update.new(actor: current_user, team: @team, request_id: request.request_id).call(team_params)
        render_data(SaasPresenter.team(@team))
      end

      private

      def team_params
        attributes_for(:team, %i[name timezone locale])
      end

      def load_team
        @team = policy_scope(Team).find(params.expect(:id))
        Current.team = @team
      end
    end
  end
end

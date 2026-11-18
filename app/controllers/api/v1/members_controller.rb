# frozen_string_literal: true

module API
  module V1
    class MembersController < TeamContextController
      def index
        authorize @team, :show?
        render_collection(@team.active_members.includes(:user)) { |member| SaasPresenter.member(member) }
      end

      def update
        authorize @team.active_members.find(params.expect(:id)), :update?
        member = Members::ChangeRole.new(**operation_options).call(params[:id], member_role)
        render_data(SaasPresenter.member(member))
      end

      def destroy
        authorize @team.active_members.find(params.expect(:id)), :destroy?
        Members::Remove.new(**operation_options).call(params[:id])
        head :no_content
      end

      private

      def member_role
        attributes_for(:member, [:role]).fetch(:role) { raise ActionController::ParameterMissing, :role }
      end
    end
  end
end

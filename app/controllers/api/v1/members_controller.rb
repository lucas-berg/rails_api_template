# frozen_string_literal: true

module API
  module V1
    class MembersController < TeamContextController
      def index
        authorize!(:read, @team)
        render_collection(@team.active_members.includes(:user)) { |member| SaasPresenter.member(member) }
      end

      def update
        role = attributes_for(:member, [:role]).fetch(:role) { raise ActionController::ParameterMissing, :role }
        member = Members::ChangeRole.new(**operation_options).call(params[:id], role)
        render_data(SaasPresenter.member(member))
      end

      def destroy
        Members::Remove.new(**operation_options).call(params[:id])
        head :no_content
      end
    end
  end
end

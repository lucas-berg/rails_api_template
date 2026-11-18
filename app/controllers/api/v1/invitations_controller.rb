# frozen_string_literal: true

module API
  module V1
    class InvitationsController < TeamContextController
      def index
        authorize!(:update, @team)
        relation = @team.invitations
        unless @team.active_members.find_by!(user_id: current_user.id).owner?
          relation = relation.where(role: %w[member viewer])
        end
        render_collection(relation) { |invitation| SaasPresenter.invitation(invitation) }
      end

      def create
        attributes = attributes_for(:invitation, %i[email role])
        email = attributes.fetch(:email) { raise ActionController::ParameterMissing, :email }
        invitation = Invitations::Create.new(**operation_options).call(email:, role: attributes.fetch(:role, 'member'))
        render_data(SaasPresenter.invitation(invitation), status: :created)
      end

      def resend
        invitation = Invitations::Resend.new(**operation_options).call(params[:id])
        render_data(SaasPresenter.invitation(invitation))
      end

      def destroy
        Invitations::Revoke.new(**operation_options).call(params[:id])
        head :no_content
      end
    end
  end
end

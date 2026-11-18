# frozen_string_literal: true

module API
  module V1
    class TeamOnboardingController < TeamContextController
      def show
        authorize!(:read, @team)
        steps = [{ key: 'verify_email', completed: current_user.confirmed? },
                 { key: 'join_team', completed: true }]
        steps << invitation_step if Authorization.allowed?(current_user, :update, @team)
        render_data({ steps: })
      end

      private

      def invitation_step
        completed = @team.active_members.where.not(user_id: current_user.id).exists? ||
                    @team.invitations.where(revoked_at: nil).exists?(['expires_at > ?', Time.current])
        { key: 'invite_teammate', completed:, actionable: @team.active? }
      end
    end
  end
end

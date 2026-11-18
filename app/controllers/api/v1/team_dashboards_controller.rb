# frozen_string_literal: true

module API
  module V1
    class TeamDashboardsController < TeamContextController
      def show
        authorize @team, :show?
        membership = @team.active_members.find_by!(user_id: current_user.id)
        render_data({ team: SaasPresenter.team(@team), role: membership.role, counts: counts(membership),
                      preferences: effective_preferences })
      end

      private

      def effective_preferences
        current_user.preferences.reverse_merge('locale' => @team.locale, 'timezone' => @team.timezone)
      end

      def counts(membership)
        result = {
          members: @team.active_members.count,
          unread_notifications: Notification.visible_to(current_user).where(team: @team, read_at: nil).count
        }
        result[:pending_invitations] = pending_invitations if membership.owner? || membership.admin?
        result
      end

      def pending_invitations
        @team.invitations.where(accepted_at: nil, revoked_at: nil).where('expires_at > ?', Time.current).count
      end
    end
  end
end

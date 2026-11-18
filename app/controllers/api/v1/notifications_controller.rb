# frozen_string_literal: true

module API
  module V1
    class NotificationsController < TeamContextController
      def index
        authorize @team, :show?
        render_collection(notifications, &:presentation)
      end

      def read
        notification = notifications.find(params.expect(:id))
        authorize notification, :mark_read?
        notification.mark_read!
        render_data(notification.presentation)
      end

      private

      def notifications
        policy_scope(Notification).where(team_id: @team.id).includes(:user, :team)
      end
    end
  end
end

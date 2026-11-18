# frozen_string_literal: true

module API
  module V1
    class NotificationsController < TeamContextController
      def index
        authorize!(:read, @team)
        render_collection(notifications, &:presentation)
      end

      def read
        notification = notifications.find(params.expect(:id))
        authorize!(:mark_read, notification)
        notification.mark_read!
        render_data(notification.presentation)
      end

      private

      def notifications
        Notification.visible_to(current_user).where(team_id: @team.id).includes(:user, :team)
      end
    end
  end
end

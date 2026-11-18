# frozen_string_literal: true

class NotificationPolicy
  def initialize(user, notification)
    @user = user
    @notification = notification
  end

  def allowed?(action)
    %i[read mark_read].include?(action) && @user&.active_for_authentication? && @notification.readable_by?(@user)
  end
end

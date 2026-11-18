# frozen_string_literal: true

class NotificationPreferencePolicy < ApplicationPolicy
  def show?
    verified_user? && record.user_id == user.id
  end

  alias update? show?
end

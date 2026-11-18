# frozen_string_literal: true

class NotificationPolicy < ApplicationPolicy
  def show?
    verified_user? && record.readable_by?(user)
  end

  alias mark_read? show?

  class Scope < ApplicationPolicy::Scope
    def resolve
      verified_user? ? scope.merge(Notification.visible_to(user)) : scope.none
    end
  end
end

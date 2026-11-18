# frozen_string_literal: true

class AuthSessionPolicy < ApplicationPolicy
  def destroy?
    verified_user? && record.user_id == user.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      verified_user? ? scope.where(user_id: user.id) : scope.none
    end
  end
end

# frozen_string_literal: true

class DeletionRequestPolicy < ApplicationPolicy
  def show?
    verified_user? && record.requested_by_id == user.id
  end

  alias cancel? show?

  class Scope < ApplicationPolicy::Scope
    def resolve
      verified_user? ? scope.where(requested_by_id: user.id) : scope.none
    end
  end
end

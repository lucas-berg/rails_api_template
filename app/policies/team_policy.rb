# frozen_string_literal: true

class TeamPolicy < ApplicationPolicy
  def create?
    verified_user?
  end

  def show?
    membership_for(record).present?
  end

  def update?
    %w[owner admin].include?(membership_for(record)&.role)
  end

  alias audit? update?

  def transfer_ownership?
    membership_for(record)&.owner? == true
  end

  alias request_deletion? transfer_ownership?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless verified_user?

      scope.accessible.where(id: user.active_members.select(:team_id))
    end
  end
end

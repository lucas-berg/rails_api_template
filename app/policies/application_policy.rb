# frozen_string_literal: true

class ApplicationPolicy
  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  alias show? index?
  alias create? index?
  alias update? index?
  alias destroy? index?

  def new?
    create?
  end

  def edit?
    update?
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope.none
    end

    private

    attr_reader :user, :scope

    def verified_user?
      user.is_a?(User) && user.active_for_authentication? && user.confirmed?
    end
  end

  private

  attr_reader :user, :record

  def verified_user?
    user.is_a?(User) && user.active_for_authentication? && user.confirmed?
  end

  def membership_for(team)
    team.active_members.find_by(user_id: user.id) if verified_user? && team.accessible?
  end
end

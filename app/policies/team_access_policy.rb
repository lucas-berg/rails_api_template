# frozen_string_literal: true

class TeamAccessPolicy
  def initialize(user, resource, team = resource)
    @user = user
    @resource = resource
    @team = team
  end

  private

  def verified_user?
    @user&.active_for_authentication? && @user.confirmed?
  end

  def membership
    @team.active_members.find_by(user_id: @user.id) if verified_user? && @team.accessible?
  end
end

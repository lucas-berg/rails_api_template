# frozen_string_literal: true

class MemberPolicy < TeamAccessPolicy
  def allowed?(action)
    member = membership
    return false unless member && @resource.team_id == @team.id
    return true if action == :read

    %i[update remove].include?(action) && manageable?(member)
  end

  private

  def manageable?(member)
    roles = { 'owner' => %w[owner admin member viewer], 'admin' => %w[member viewer] }
    roles.fetch(member.role, []).include?(@resource.role)
  end
end

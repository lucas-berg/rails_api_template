# frozen_string_literal: true

class DataExportPolicy < TeamAccessPolicy
  def allowed?(action)
    return false unless %i[create read download].include?(action)
    return false unless owned_export?

    member = membership
    member && %w[owner admin].include?(member.role) && %w[active suspended].include?(@team.status)
  end

  private

  def owned_export?
    @resource.team_id == @team.id && @resource.requested_by_id == @user&.id
  end
end

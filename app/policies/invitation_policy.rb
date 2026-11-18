# frozen_string_literal: true

class InvitationPolicy < TeamAccessPolicy
  def allowed?(action)
    member = membership
    return false unless member && @resource.team_id == @team.id
    return false unless %i[read create resend revoke].include?(action)

    member.owner? || (member.admin? && %w[member viewer].include?(@resource.role))
  end
end

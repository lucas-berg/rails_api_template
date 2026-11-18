# frozen_string_literal: true

class TeamPolicy < TeamAccessPolicy
  PERMISSIONS = {
    read: %w[owner admin member viewer], update: %w[owner admin],
    audit: %w[owner admin], transfer_ownership: ['owner']
  }.freeze

  def allowed?(action)
    return verified_user? if action == :create

    member = membership
    member && PERMISSIONS.fetch(action, []).include?(member.role)
  end
end

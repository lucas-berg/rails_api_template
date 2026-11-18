# frozen_string_literal: true

class InvitationPolicy < ApplicationPolicy
  def create?
    member = membership_for(record.team)
    member&.owner? || (member&.admin? && %w[member viewer].include?(record.role)) || false
  end

  alias show? create?
  alias resend? create?
  alias destroy? create?

  def accept?
    verified_user? && user.email == record.normalized_email
  end
end

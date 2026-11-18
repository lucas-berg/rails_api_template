# frozen_string_literal: true

class MemberPolicy < ApplicationPolicy
  def show?
    membership_for(record.team).present?
  end

  def update?
    member = membership_for(record.team)
    roles = { 'owner' => %w[owner admin member viewer], 'admin' => %w[member viewer] }
    roles.fetch(member&.role, []).include?(record.role)
  end

  alias destroy? update?

  def grant_admin?
    membership_for(record.team)&.owner? == true
  end
end

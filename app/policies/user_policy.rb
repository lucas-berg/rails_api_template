# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def show?
    verified_user? && record.id == user.id
  end

  alias update? show?
  alias request_deletion? show?
end

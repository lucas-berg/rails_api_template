# frozen_string_literal: true

module Admin
  class AdminUserPolicy < ApplicationPolicy
    def create?
      super_admin?
    end

    alias update? create?
  end
end

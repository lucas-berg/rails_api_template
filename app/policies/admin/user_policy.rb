# frozen_string_literal: true

module Admin
  class UserPolicy < ApplicationPolicy
    def suspend?
      super_admin?
    end

    alias restore? suspend?
  end
end

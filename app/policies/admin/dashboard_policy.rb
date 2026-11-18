# frozen_string_literal: true

module Admin
  class DashboardPolicy < ApplicationPolicy
    def manage_tools?
      super_admin?
    end
  end
end

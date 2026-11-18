# frozen_string_literal: true

module Admin
  class ApplicationPolicy < ::ApplicationPolicy
    def index?
      user.is_a?(AdminUser)
    end

    alias show? index?

    class Scope < ::ApplicationPolicy::Scope
      def resolve
        user.is_a?(AdminUser) ? scope.all : scope.none
      end
    end

    private

    def super_admin?
      user.is_a?(AdminUser) && user.super_admin?
    end
  end
end

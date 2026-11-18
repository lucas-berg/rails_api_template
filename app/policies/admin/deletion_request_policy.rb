# frozen_string_literal: true

module Admin
  class DeletionRequestPolicy < ApplicationPolicy
    def retry_cleanup?
      super_admin?
    end
  end
end

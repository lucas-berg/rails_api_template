# frozen_string_literal: true

module Admin
  class MailDeliveryPolicy < ApplicationPolicy
    def retry_delivery?
      super_admin?
    end
  end
end

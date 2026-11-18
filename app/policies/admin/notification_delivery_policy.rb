# frozen_string_literal: true

module Admin
  class NotificationDeliveryPolicy < ApplicationPolicy
    def retry_delivery?
      super_admin?
    end
  end
end

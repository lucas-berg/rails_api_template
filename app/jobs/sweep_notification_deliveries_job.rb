# frozen_string_literal: true

class SweepNotificationDeliveriesJob < ApplicationJob
  queue_as :mailers

  def perform
    NotificationDelivery.due.limit(500).pluck(:id).each do |delivery_id|
      SendNotificationDeliveryJob.perform_later(delivery_id)
    end
  end
end

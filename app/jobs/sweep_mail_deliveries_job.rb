# frozen_string_literal: true

class SweepMailDeliveriesJob < ApplicationJob
  queue_as :mailers

  def perform
    MailDelivery.due.limit(500).pluck(:id).each do |delivery_id|
      SendMailDeliveryJob.perform_later(delivery_id)
    end
  end
end

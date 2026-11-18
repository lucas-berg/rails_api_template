# frozen_string_literal: true

class SendMailDeliveryJob < ApplicationJob
  queue_as :mailers

  def perform(delivery_id)
    delivery = MailDelivery.find_by(id: delivery_id)
    return unless delivery

    lease = delivery.claim!
    return unless lease

    send_claimed(delivery, lease)
  end

  private

  def send_claimed(delivery, lease)
    message = MailDeliveryMessage.new(delivery).build
    if message
      message.deliver_now
      delivery.finish!(lease)
    else
      delivery.finish!(lease, status: 'skipped')
    end
  rescue StandardError => exception
    delivery.fail!(lease, exception)
  end
end

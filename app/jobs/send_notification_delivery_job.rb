# frozen_string_literal: true

class SendNotificationDeliveryJob < ApplicationJob
  queue_as :mailers

  def perform(delivery_id)
    delivery = NotificationDelivery.find_by(id: delivery_id)
    return unless delivery

    lease = delivery.claim!
    send_claimed(delivery, lease) if lease
  end

  private

  # The worker owns delivery orchestration; the model owns the lease and state transitions.
  # :reek:FeatureEnvy
  def send_claimed(delivery, lease)
    notification = delivery.notification
    Current.set(user: notification.user, team: notification.team) do
      if should_deliver?(notification)
        NotificationMailer.notice(notification).deliver_now
        delivery.finish!(lease)
      else
        delivery.finish!(lease, status: 'skipped')
      end
    end
  rescue StandardError => exception
    delivery.fail!(lease, exception)
  ensure
    Current.reset
  end

  def should_deliver?(notification)
    notification.deliverable? && NotificationPreference.for(notification.user).allows?(notification.category, 'email')
  end
end

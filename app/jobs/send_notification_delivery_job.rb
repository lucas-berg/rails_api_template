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

  # The worker reconstructs correlation fields from its trusted notification record.
  # :reek:FeatureEnvy
  def execution_context
    notification = NotificationDelivery.find_by(id: arguments.first)&.notification
    return {} unless notification

    { user: notification.user, team: notification.team }
  end

  # The worker owns delivery orchestration; the model owns the lease and state transitions.
  # :reek:FeatureEnvy
  def send_claimed(delivery, lease)
    notification = delivery.notification
    if should_deliver?(notification)
      NotificationMailer.notice(notification).deliver_now
      delivery.finish!(lease)
    else
      delivery.finish!(lease, status: 'skipped')
    end
  rescue StandardError => exception
    delivery.fail!(lease, exception)
  end

  def should_deliver?(notification)
    notification.deliverable? && NotificationPreference.for(notification.user).allows?(notification.category, 'email')
  end
end

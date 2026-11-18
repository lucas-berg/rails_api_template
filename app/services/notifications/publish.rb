# frozen_string_literal: true

module Notifications
  class Publish
    def self.call(user:, kind:, event_key:, team: nil)
      new(user:, kind:, event_key:, team:).call
    end

    def initialize(user:, kind:, event_key:, team: nil)
      @user = user
      @kind = kind.to_s
      @event_key = event_key
      @team = team
    end

    def call
      Notification.transaction do
        notification = find_or_create_notification
        verify_event!(notification)
        create_deliveries(notification) if notification.previously_new_record?
        notification
      end
    end

    private

    def find_or_create_notification
      Notification.create_or_find_by!(user_id: @user.id, event_key: @event_key) do |notification|
        notification.assign_attributes(user: @user, kind: @kind, team: @team, category: Catalog.category(@kind))
      end
    end

    def verify_event!(notification)
      return if notification.kind == @kind && notification.team_id == @team&.id

      raise ArgumentError, 'The event key has already been used for another notification'
    end

    def create_deliveries(notification)
      preferences = NotificationPreference.for(@user)
      @delivery_allowed = notification.deliverable?
      %w[in_app email].each do |channel|
        record_delivery(notification, channel, preferences)
      end
    end

    # This transaction coordinates the visible notification with its durable delivery receipt.
    # :reek:FeatureEnvy
    def record_delivery(notification, channel, preferences)
      status = delivery_status(notification, channel, preferences)
      timestamp = Time.current
      sent_at = timestamp if status == 'sent'
      notification.update!(visible_at: timestamp) if channel == 'in_app' && sent_at
      notification.notification_deliveries.create!(channel:, status:, next_attempt_at: timestamp, sent_at:)
    end

    def delivery_status(notification, channel, preferences)
      return 'skipped' unless @delivery_allowed && preferences.allows?(notification.category, channel)

      channel == 'in_app' ? 'sent' : 'pending'
    end
  end
end

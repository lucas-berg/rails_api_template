# frozen_string_literal: true

class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_notification_preferences
    create_notifications
    create_notification_deliveries
  end

  private

  def create_notification_preferences
    create_table :notification_preferences do |t|
      t.references :user, type: :integer, null: false, foreign_key: true, index: { unique: true }
      t.boolean :activity_in_app, default: true, null: false
      t.boolean :activity_email, default: false, null: false
      t.timestamps
    end
  end

  def create_notifications
    create_table :notifications do |t|
      t.references :user, type: :integer, null: false, foreign_key: true
      t.references :team, foreign_key: true
      t.string :event_key, null: false
      t.string :kind, null: false
      t.string :category, null: false
      t.datetime :visible_at
      t.datetime :read_at
      t.timestamps
    end
    add_index :notifications, %i[user_id event_key], unique: true
    add_index :notifications, %i[user_id team_id created_at]
    add_check_constraint :notifications,
                         "(category = 'security' AND team_id IS NULL) OR (category = 'activity' AND team_id IS NOT NULL)",
                         name: 'notifications_category_team'
  end

  def create_notification_deliveries
    create_table :notification_deliveries do |t|
      t.references :notification, null: false, foreign_key: true
      t.string :channel, null: false
      t.string :status, default: 'pending', null: false
      t.integer :attempts, default: 0, null: false
      t.datetime :next_attempt_at, null: false
      t.datetime :locked_at
      t.string :lease_token
      t.datetime :sent_at
      t.string :last_error
      t.timestamps
    end
    add_index :notification_deliveries, %i[notification_id channel], unique: true
    add_index :notification_deliveries, %i[channel status next_attempt_at], name: 'index_notification_deliveries_due'
    add_check_constraint :notification_deliveries, "channel IN ('in_app', 'email')", name: 'notification_channels_allowed'
    add_check_constraint :notification_deliveries, "status IN ('pending', 'sending', 'sent', 'failed', 'skipped')",
                         name: 'notification_delivery_status_allowed'
    add_check_constraint :notification_deliveries, 'attempts >= 0', name: 'notification_attempts_nonnegative'
  end
end

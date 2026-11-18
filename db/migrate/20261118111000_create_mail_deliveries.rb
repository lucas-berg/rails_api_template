# frozen_string_literal: true

class CreateMailDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :mail_deliveries do |t|
      t.references :user, type: :integer, foreign_key: { on_delete: :nullify }
      t.bigint :team_id
      t.string :kind, null: false
      t.string :event_key, null: false
      t.text :encrypted_payload
      t.string :status, null: false, default: 'pending'
      t.integer :attempts, null: false, default: 0
      t.datetime :next_attempt_at, null: false
      t.datetime :locked_at
      t.string :lease_token
      t.datetime :sent_at
      t.string :last_error
      t.timestamps
    end

    add_index :mail_deliveries, :event_key, unique: true
    add_index :mail_deliveries, :team_id
    add_index :mail_deliveries, %i[status next_attempt_at]
    add_index :mail_deliveries, %i[status locked_at]
    add_check_constraint :mail_deliveries, "status IN ('pending', 'sending', 'sent', 'failed', 'skipped')",
                         name: 'mail_deliveries_status_valid'
    add_check_constraint :mail_deliveries, 'attempts >= 0', name: 'mail_deliveries_attempts_valid'
  end
end

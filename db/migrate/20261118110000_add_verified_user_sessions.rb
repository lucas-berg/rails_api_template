# frozen_string_literal: true

class AddVerifiedUserSessions < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.string :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string :unconfirmed_email
      t.string :status, default: 'active', null: false
      t.integer :credentials_version, default: 0, null: false
    end
    add_index :users, :confirmation_token, unique: true
    add_check_constraint :users, "status IN ('active', 'suspended')", name: 'users_status_allowed'
    add_check_constraint :users, 'credentials_version >= 0', name: 'users_credentials_version_nonnegative'

    create_table :auth_sessions do |t|
      t.references :user, type: :integer, null: false, foreign_key: true
      t.string :jti_digest, null: false
      t.integer :credentials_version, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.datetime :last_used_at
      t.timestamps
    end
    add_index :auth_sessions, :jti_digest, unique: true
    add_index :auth_sessions, :expires_at
    add_check_constraint :auth_sessions, 'credentials_version >= 0', name: 'auth_sessions_version_nonnegative'
  end
end

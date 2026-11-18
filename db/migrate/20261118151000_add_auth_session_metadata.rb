# frozen_string_literal: true

class AddAuthSessionMetadata < ActiveRecord::Migration[8.1]
  def change
    change_table :auth_sessions, bulk: true do |t|
      t.string :user_agent, limit: 256
      t.inet :ip_address
    end
  end
end

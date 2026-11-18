# frozen_string_literal: true

class RemoveTracingAPIKeyFromUsers < ActiveRecord::Migration[8.1]
  def up
    # PostgreSQL also removes indexes that depend on the dropped column.
    remove_column :users, :tracing_api_key, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Removed tracing API keys cannot be recovered by rolling back'
  end
end

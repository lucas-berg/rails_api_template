# frozen_string_literal: true

class AddLifecycleLookupIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :audit_events, %i[actor_type actor_id], algorithm: :concurrently
    add_index :audit_events, %i[target_type target_id], algorithm: :concurrently
    add_index :deletion_tombstones, %i[subject_type subject_id], algorithm: :concurrently
  end
end

# frozen_string_literal: true

class CreateDataLifecycle < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :deleted_at, :datetime
    add_column :teams, :deleted_at, :datetime
    remove_check_constraint :teams, "status IN ('active', 'suspended')", name: 'teams_status_allowed'
    add_check_constraint :teams, "status IN ('active', 'suspended', 'deletion_pending', 'deleting', 'deleted')", name: 'teams_status_allowed'
    create_exports
    create_deletion_requests
    create_table :deletion_tombstones do |t|
      t.string :request_uuid, null: false
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.string :fingerprint, null: false
      t.datetime :deleted_at, null: false
      t.timestamps
    end
    add_index :deletion_tombstones, :request_uuid, unique: true
    add_check_constraint :deletion_tombstones, "subject_type IN ('User','Team')", name: 'deletion_tombstones_subject_allowed'
  end

  private

  def create_exports
    create_table :data_exports do |t|
      t.references :team, null: false, foreign_key: true
      t.references :requested_by, type: :integer, null: false, foreign_key: { to_table: :users }
      t.string :status, default: 'pending', null: false
      t.integer :attempts, default: 0, null: false
      t.references :staging_blob, foreign_key: { to_table: :active_storage_blobs, on_delete: :nullify }
      t.string :lease_token
      t.datetime :processing_started_at
      t.datetime :expires_at
      t.string :failure_code
      t.timestamps
    end
    add_index :data_exports, %i[status expires_at]
    add_check_constraint :data_exports, "status IN ('pending','processing','ready','failed','expired')", name: 'data_exports_status_allowed'
    add_check_constraint :data_exports, 'attempts >= 0', name: 'data_exports_attempts_nonnegative'
  end

  def create_deletion_requests
    create_table :deletion_requests do |t|
      t.string :uuid, null: false
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.references :requested_by, type: :integer, foreign_key: { to_table: :users }
      t.string :status, default: 'pending', null: false
      t.string :stage, default: 'requested', null: false
      t.string :previous_team_status
      t.datetime :scheduled_at, null: false
      t.datetime :processing_started_at
      t.datetime :completed_at
      t.datetime :canceled_at
      t.string :failure_code
      t.integer :attempts, default: 0, null: false
      t.text :encrypted_recipient
      t.datetime :notified_at
      t.integer :notice_attempts, default: 0, null: false
      t.string :notice_failure_code
      t.timestamps
    end
    add_deletion_constraints
  end

  def add_deletion_constraints
    add_index :deletion_requests, :uuid, unique: true
    add_index :deletion_requests, %i[subject_type subject_id], unique: true,
                                                               where: "status IN ('pending','processing','failed')", name: 'index_deletion_requests_on_open_subject'
    add_index :deletion_requests, %i[status scheduled_at]
    add_check_constraint :deletion_requests, "status IN ('pending','processing','failed','completed','canceled')", name: 'deletion_requests_status_allowed'
    add_check_constraint :deletion_requests, "stage IN ('requested','ledger','files','exports','records','completed')", name: 'deletion_requests_stage_allowed'
    add_check_constraint :deletion_requests, "subject_type IN ('User','Team')", name: 'deletion_requests_subject_allowed'
    add_check_constraint :deletion_requests, 'attempts >= 0 AND notice_attempts >= 0', name: 'deletion_requests_attempts_nonnegative'
  end
end

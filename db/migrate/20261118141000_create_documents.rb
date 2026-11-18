# frozen_string_literal: true

class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.references :team, null: false, foreign_key: true
      t.references :uploader, type: :integer, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: 'uploading'
      t.string :original_filename, null: false
      t.string :declared_content_type, null: false
      t.string :verified_content_type
      t.bigint :byte_size, null: false
      t.string :failure_code
      t.datetime :upload_expires_at, null: false
      t.datetime :verification_requested_at
      t.datetime :verified_at
      t.datetime :purge_requested_at
      t.datetime :purged_at
      t.integer :purge_attempts, null: false, default: 0
      t.string :last_error
      t.timestamps
    end

    add_document_constraints
    add_reference :users, :avatar_document, foreign_key: { to_table: :documents, on_delete: :nullify }
  end

  private

  def add_document_constraints
    add_index :documents, %i[status upload_expires_at]
    add_index :documents, %i[status verification_requested_at]
    add_index :documents, %i[status purge_requested_at]
    add_check_constraint :documents, "status IN ('uploading', 'processing', 'ready', 'rejected', 'deleting', 'deleted', 'purge_failed')",
                         name: 'documents_status_valid'
    add_check_constraint :documents, 'byte_size >= 0 AND purge_attempts >= 0', name: 'documents_counts_valid'
  end
end

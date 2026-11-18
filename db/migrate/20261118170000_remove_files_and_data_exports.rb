# frozen_string_literal: true

# Stop the old web and GoodJob processes before applying this migration.
# Attachment associations are removed, but blob metadata and stored bytes are retained.
class RemoveFilesAndDataExports < ActiveRecord::Migration[8.1]
  REMOVED_JOBS = %w[VerifyDocumentJob PurgeDocumentJob CleanupDocumentsJob
                    BuildDataExportJob CleanupDataExportsJob].freeze

  def up
    remove_obsolete_jobs
    remove_export_notifications
    simplify_deletion_stages
    execute "DELETE FROM active_storage_attachments WHERE record_type IN ('Document', 'DataExport')"
    remove_reference :users, :avatar_document, foreign_key: { to_table: :documents }
    drop_table :data_exports
    drop_table :documents
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Restore a pre-migration backup to recover removed module records'
  end

  private

  def remove_obsolete_jobs
    execute 'LOCK TABLE good_jobs IN SHARE ROW EXCLUSIVE MODE'
    running = select_value(<<~SQL.squish)
      SELECT EXISTS (SELECT 1 FROM good_jobs WHERE (#{removed_job_filter})
        AND finished_at IS NULL AND (locked_by_id IS NOT NULL OR locked_at IS NOT NULL))
    SQL
    raise 'Stop old workers and resolve claimed file/export jobs before migrating' if running

    remove_job_dependents
    execute "DELETE FROM good_jobs WHERE #{removed_job_filter}"
  end

  def remove_job_dependents
    execute <<~SQL.squish
      DELETE FROM good_job_executions
      WHERE job_class IN (#{removed_job_classes})
        OR active_job_id IN (SELECT active_job_id FROM good_jobs WHERE #{removed_job_filter})
    SQL
    execute <<~SQL.squish
      DELETE FROM good_job_concurrency_claims
      WHERE job_id IN (SELECT id FROM good_jobs WHERE #{removed_job_filter})
         OR job_id IN (SELECT active_job_id FROM good_jobs WHERE #{removed_job_filter})
    SQL
    execute <<~SQL.squish
      UPDATE good_jobs SET retried_good_job_id = NULL
      WHERE retried_good_job_id IN (SELECT id FROM good_jobs WHERE #{removed_job_filter})
    SQL
  end

  def removed_job_filter
    "job_class IN (#{removed_job_classes}) OR serialized_params->>'job_class' IN (#{removed_job_classes})"
  end

  def removed_job_classes
    REMOVED_JOBS.map { |name| connection.quote(name) }.join(', ')
  end

  def remove_export_notifications
    execute <<~SQL.squish
      DELETE FROM notification_deliveries
      WHERE notification_id IN (SELECT id FROM notifications WHERE kind = 'export.ready')
    SQL
    execute "DELETE FROM notifications WHERE kind = 'export.ready'"
  end

  def simplify_deletion_stages
    execute "UPDATE deletion_requests SET stage = 'records' WHERE stage IN ('files', 'exports')"
    remove_check_constraint :deletion_requests, name: 'deletion_requests_stage_allowed'
    add_check_constraint :deletion_requests, "stage IN ('requested', 'ledger', 'records', 'completed')",
                         name: 'deletion_requests_stage_allowed'
  end
end

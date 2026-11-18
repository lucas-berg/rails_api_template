# frozen_string_literal: true

# Stop old web and worker processes before applying this irreversible module removal.
class RemoveDeletionLifecycle < ActiveRecord::Migration[8.1]
  REMOVED_JOBS = %w[ProcessDeletionJob SweepDeletionsJob SendDeletionNoticeJob].freeze

  def up
    remove_obsolete_jobs
    preserve_unavailable_accounts
    simplify_team_statuses
    execute <<~SQL.squish
      DELETE FROM notification_deliveries
      WHERE notification_id IN (SELECT id FROM notifications WHERE kind LIKE 'deletion.%')
    SQL
    execute "DELETE FROM notifications WHERE kind LIKE 'deletion.%'"
    drop_table :deletion_requests
    drop_table :deletion_tombstones
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Restore a pre-migration backup to recover deletion lifecycle records'
  end

  private

  def preserve_unavailable_accounts
    # Old requests may have crossed their irreversible boundary before setting deleted_at.
    execute <<~SQL.squish
      UPDATE users SET status = 'suspended', deleted_at = COALESCE(deleted_at, CURRENT_TIMESTAMP),
        credentials_version = credentials_version + 1
      WHERE id IN (SELECT subject_id FROM deletion_requests
        WHERE subject_type = 'User' AND stage <> 'requested' AND status IN ('processing', 'failed', 'completed'))
    SQL
    execute <<~SQL.squish
      UPDATE auth_sessions SET revoked_at = CURRENT_TIMESTAMP
      WHERE revoked_at IS NULL AND user_id IN (SELECT id FROM users WHERE deleted_at IS NOT NULL)
    SQL
  end

  def simplify_team_statuses
    execute <<~SQL.squish
      UPDATE teams SET status = 'deleted', deleted_at = COALESCE(deleted_at, CURRENT_TIMESTAMP)
      WHERE status = 'deleting' OR id IN (SELECT subject_id FROM deletion_requests
        WHERE subject_type = 'Team' AND stage <> 'requested' AND status IN ('processing', 'failed', 'completed'))
    SQL
    execute "UPDATE teams SET status = 'suspended' WHERE status = 'deletion_pending'"
    remove_check_constraint :teams, name: 'teams_status_allowed'
    add_check_constraint :teams, "status IN ('active', 'suspended', 'deleted')", name: 'teams_status_allowed'
  end

  def remove_obsolete_jobs
    execute 'LOCK TABLE good_jobs IN SHARE ROW EXCLUSIVE MODE'
    running = select_value(<<~SQL.squish)
      SELECT EXISTS (SELECT 1 FROM good_jobs WHERE (#{removed_job_filter})
        AND finished_at IS NULL AND (locked_by_id IS NOT NULL OR locked_at IS NOT NULL))
    SQL
    raise 'Stop old workers and resolve claimed deletion jobs before migrating' if running

    remove_job_dependents
    execute "DELETE FROM good_jobs WHERE #{removed_job_filter}"
  end

  def remove_job_dependents
    execute <<~SQL.squish
      DELETE FROM good_job_executions WHERE job_class IN (#{removed_job_classes})
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
end

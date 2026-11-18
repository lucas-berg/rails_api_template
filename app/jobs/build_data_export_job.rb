# frozen_string_literal: true

# An export and its lease deliberately travel together across each worker stage.
# :reek:DataClump
class BuildDataExportJob < ApplicationJob
  queue_as :default

  def perform(export_id)
    Lifecycle::ExecutionLock.with(namespace: 72_127, id: export_id) { build(export_id) }
  end

  private

  # Context only supplies identifiers; authorization remains in the worker.
  # :reek:FeatureEnvy
  def execution_context
    export = DataExport.find_by(id: arguments.first)
    return {} unless export

    { user: export.requested_by, team: export.team }
  end

  def build(export_id)
    export = DataExport.find_by(id: export_id)
    lease = export&.claim!
    return unless lease

    authorize!(export)
    DataExports::Staging.purge!(export)
    upload_snapshot(export, lease)
  rescue StandardError => error
    fail_export(export, lease, error)
  end

  def upload_snapshot(export, lease)
    Tempfile.create(['team-export-', '.json']) do |file|
      DataExports::Snapshot.new(export.team).write(file)
      blob = DataExports::Staging.prepare!(export, lease, file)
      # The committed staging reference survives upload exceptions and worker crashes.
      blob.upload_without_unfurling(file)
      publish(export, lease, blob)
    end
  end

  # The worker refreshes both sides of the authorization boundary before publishing.
  # :reek:FeatureEnvy
  def authorize!(export)
    user = export.requested_by.reload
    team = export.team.reload
    raise Authorization::Forbidden unless DataExportPolicy.new(user, export, team).allowed?(:create)
  end

  # The lease is an ownership token, not a request option.
  # :reek:FeatureEnvy
  # :reek:ControlParameter
  def publish(export, lease, blob)
    export.team.with_lock do
      export.with_lock do
        authorize!(export)
        next unless export.lease_token == lease && export.status == 'processing'

        publish_record!(export, blob)
      end
    end
  end

  def publish_record!(export, blob)
    export.file.attach(blob)
    export.update!(status: 'ready', expires_at: 24.hours.from_now, lease_token: nil, staging_blob: nil)
    Notifications::Publish.call(user: export.requested_by, kind: 'export.ready',
                                event_key: "export:#{export.id}:ready", team: export.team)
  end

  # Failed storage I/O leaves its staging reference for the next attempt or cleanup sweep.
  # :reek:FeatureEnvy
  # :reek:ControlParameter
  def fail_export(export, lease, error)
    raise error unless export
    return unless DataExport.exists?(id: export.id)

    export.with_lock do
      next unless export.lease_token == lease

      attempts = error.is_a?(Authorization::Forbidden) ? 5 : export.attempts
      export.update!(status: 'failed', failure_code: error.class.name, lease_token: nil, attempts: attempts)
    end
  end
end

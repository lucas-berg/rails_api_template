# frozen_string_literal: true

class CleanupDataExportsJob < ApplicationJob
  def perform
    expire_abandoned
    purge_expired
    purge_exhausted
    DataExport.where(status: %w[pending failed]).where(attempts: ...5).find_each(&:enqueue)
    DataExport.where(status: 'processing', processing_started_at: ...10.minutes.ago).find_each(&:enqueue)
  end

  private

  def expire_abandoned
    DataExport.where(status: 'processing', attempts: 5..,
                     processing_started_at: ...10.minutes.ago).find_each do |export|
      Lifecycle::ExecutionLock.with(namespace: 72_127, id: export.id) do
        export.with_lock do
          if export.status == 'processing'
            export.update!(status: 'failed', lease_token: nil,
                           failure_code: 'attempts_exhausted')
          end
        end
      end
    end
  end

  def purge_expired
    DataExport.where(status: %w[ready expired]).where(expires_at: ..Time.current).find_each do |export|
      Lifecycle::ExecutionLock.with(namespace: 72_127, id: export.id) do
        export.with_lock { export.update!(status: 'expired') }
        Lifecycle::PurgeAttachment.call(export.file)
        DataExports::Staging.purge!(export)
      end
    end
  end

  def purge_exhausted
    DataExport.where(status: 'failed', attempts: 5..).where.not(staging_blob_id: nil).find_each do |export|
      Lifecycle::ExecutionLock.with(namespace: 72_127, id: export.id) { DataExports::Staging.purge!(export) }
    end
  end
end

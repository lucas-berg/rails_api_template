# frozen_string_literal: true

class SweepDeletionsJob < ApplicationJob
  def perform
    expire_abandoned
    enqueue_due
    enqueue_stale
    enqueue_notices
    clear_expired_records
  end

  private

  def expire_abandoned
    DeletionRequest.where(status: 'processing', processing_started_at: ...10.minutes.ago,
                          attempts: 8..).find_each do |record|
      Lifecycle::ExecutionLock.with(namespace: 72_125, id: record.id) do
        record.with_lock do
          record.update!(status: 'failed', failure_code: 'attempts_exhausted') if record.status == 'processing'
        end
      end
    end
  end

  def enqueue_due
    DeletionRequest.where(status: %w[pending failed], scheduled_at: ..Time.current,
                          attempts: ...8).find_each do |record|
      ProcessDeletionJob.perform_later(record.id)
    end
  end

  def enqueue_stale
    DeletionRequest.where(status: 'processing', processing_started_at: ...10.minutes.ago,
                          attempts: ...8).find_each do |record|
      ProcessDeletionJob.perform_later(record.id)
    end
  end

  def enqueue_notices
    DeletionRequest.where(status: 'completed', notified_at: nil, notice_attempts: ...8)
                   .where.not(encrypted_recipient: nil).find_each do |record|
      SendDeletionNoticeJob.perform_later(record.id)
    end
  end

  def clear_expired_records
    AuditEvent.where(occurred_at: ...365.days.ago).delete_all
    # Retention expiry must not generate new notification callbacks.
    # rubocop:disable-next Rails/SkipsModelValidations
    DeletionRequest.where(status: 'completed', completed_at: ...30.days.ago).update_all(encrypted_recipient: nil)
  end
end

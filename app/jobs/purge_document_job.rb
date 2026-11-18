# frozen_string_literal: true

# :reek:FeatureEnvy -- The job coordinates external blob deletion before committing record cleanup.
# :reek:DataClump -- Record identity and attempt generation travel together to reject stale worker results.
class PurgeDocumentJob < ApplicationJob
  queue_as :default

  def perform(document_id)
    with_purge_lock(document_id) { purge_document(document_id) }
  end

  private

  def purge_document(document_id)
    document = Document.with_attached_file.find_by(id: document_id)
    attempt = claim_attempt(document)
    return unless attempt

    blob = document.file.blob
    delete_stored_file!(document, blob) if blob
    finish_purge!(document, blob, attempt)
  rescue StandardError => exception
    record_failure(document, attempt, exception)
  end

  def with_purge_lock(document_id)
    lock_key = Digest::SHA256.digest("document-purge:#{Integer(document_id)}").unpack1('q>')
    ApplicationRecord.connection_pool.with_connection do |connection|
      acquired = connection.select_value("SELECT pg_try_advisory_lock(#{lock_key})")
      next unless acquired

      begin
        yield
      ensure
        connection.execute("SELECT pg_advisory_unlock(#{lock_key})")
      end
    end
  end

  def claim_attempt(document)
    return unless document

    document.with_lock do
      return unless purgeable?(document)

      attempt = document.purge_attempts + 1
      if attempt > 8
        document.update!(status: 'purge_failed', last_error: 'PurgeInterrupted')
        return
      end

      document.update!(purge_attempts: attempt)
      attempt
    end
  end

  def purgeable?(document)
    document && %w[deleting rejected].include?(document.status) && document.purged_at.nil?
  end

  def delete_stored_file!(document, blob)
    if blob.attachments.where.not(record: document).exists?
      raise ActiveRecord::RecordNotDestroyed, 'The file has another attachment'
    end

    # Keep the blob row and its storage key until remote deletion succeeds, so failures remain retryable.
    blob.delete
  end

  def finish_purge!(document, blob, attempt)
    document.with_lock do
      return unless current_attempt?(document, attempt)

      attachment = ActiveStorage::Attachment.find_by(record: document, name: 'file')
      attachment&.destroy!
      blob&.destroy!
      final_status = document.status == 'rejected' ? 'rejected' : 'deleted'
      document.update!(status: final_status, purged_at: Time.current, last_error: nil)
    end
  end

  def current_attempt?(document, attempt)
    purgeable?(document) && document.purge_attempts == attempt
  end

  def record_failure(document, attempt, exception)
    raise exception unless document

    document.with_lock do
      return unless current_attempt?(document, attempt)

      document.update!(status: document.purge_attempts >= 8 ? 'purge_failed' : document.status,
                       last_error: exception.class.name, purge_requested_at: Time.current)
    end
  end
end

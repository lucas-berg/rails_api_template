# frozen_string_literal: true

class CleanupDocumentsJob < ApplicationJob
  queue_as :default

  def perform
    expire_uploads
    retry_verifications
    retry_purges
  end

  private

  def expire_uploads
    now = Time.current
    Document.where(status: %w[uploading processing], upload_expires_at: ..now).find_each do |document|
      document.with_lock do
        next unless %w[uploading processing].include?(document.status)

        document.update!(status: 'rejected', failure_code: 'upload_expired', purge_requested_at: now)
      end
    end
  end

  def retry_verifications
    Document.where(status: 'processing', verification_requested_at: ..10.minutes.ago).limit(100).pluck(:id).each do |id|
      VerifyDocumentJob.perform_later(id)
    end
  end

  def retry_purges
    Document.where(status: %w[rejected deleting], purged_at: nil, purge_requested_at: ..10.minutes.ago)
            .limit(100).pluck(:id).each do |id|
      PurgeDocumentJob.perform_later(id)
    end
  end
end

# frozen_string_literal: true

class ProcessDeletionJob < ApplicationJob
  queue_as :default

  # :reek:FeatureEnvy
  def perform(deletion_id)
    deletion = DeletionRequest.find_by(id: deletion_id)
    return unless deletion

    Lifecycle::ExecutionLock.with(namespace: 72_125, id: deletion.id) { process_with_recovery(deletion.reload) }
  end

  private

  def execution_context
    JobDeletionContext.for(arguments.first)
  end

  def process_with_recovery(deletion)
    previous_attempts = deletion.attempts
    process(deletion)
  rescue StandardError => error
    record_failure(deletion, previous_attempts, error)
  end

  def process(deletion)
    return unless Deletions::BeginProcessing.call(deletion)

    Deletions::Cleanup.new(deletion.reload).call
    SendDeletionNoticeJob.perform_later(deletion.id)
  end

  def record_failure(deletion, previous_attempts, error)
    failure_code = error.class.name
    deletion.with_lock do
      next if %w[completed canceled].include?(deletion.status)

      deletion.update!(status: 'failed', failure_code: failure_code,
                       attempts: [deletion.attempts, previous_attempts.to_i + 1].max)
    end
    Rails.logger.error("Deletion failed id=#{deletion.id} error=#{failure_code}")
  end
end

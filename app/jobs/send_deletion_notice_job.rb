# frozen_string_literal: true

class SendDeletionNoticeJob < ApplicationJob
  # :reek:FeatureEnvy
  def perform(deletion_id)
    deletion = DeletionRequest.find_by(id: deletion_id)
    return unless deletion

    Lifecycle::ExecutionLock.with(namespace: 72_126, id: deletion.id) { deliver(deletion.reload) }
  rescue StandardError => error
    raise error unless deletion

    deletion.with_lock do
      deletion.update!(notice_failure_code: error.class.name) unless deletion.notified_at
    end
  end

  private

  def execution_context
    JobDeletionContext.for(arguments.first)
  end

  # A delivery updates its attempt and encrypted-address receipt together.
  # :reek:FeatureEnvy
  def deliver(deletion)
    return unless deliverable?(deletion)

    deletion.update!(notice_attempts: deletion.notice_attempts + 1)
    LifecycleMailer.deletion_completed(deletion.id).deliver_now
    deletion.update!(notified_at: Time.current, encrypted_recipient: nil, notice_failure_code: nil)
  end

  def deliverable?(deletion)
    deletion.status == 'completed' && deletion.notified_at.nil? &&
      deletion.recipient.present? && deletion.notice_attempts < 8
  end
end

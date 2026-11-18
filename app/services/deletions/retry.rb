# frozen_string_literal: true

module Deletions
  class Retry
    def self.call(actor:, deletion:, reason:, request_id: nil)
      authorize_retry!(actor, reason)

      deletion.with_lock do
        unless deletion.status == 'failed'
          raise Collaboration::Conflict.new('not_failed',
                                            'Only failed deletion requests can be retried')
        end

        deletion.update!(attempts: 0, failure_code: nil)
        team = deletion.subject if deletion.subject_type == 'Team'
        AuditEvent.record!(actor:, action: 'deletion.retried', target: deletion, team:, reason:, request_id:)
      end
      ProcessDeletionJob.perform_later(deletion.id)
      deletion
    end

    def self.authorize_retry!(actor, reason)
      raise Authorization::Forbidden unless actor.is_a?(AdminUser) && actor.super_admin?
      return if reason.to_s.strip.present?

      raise Collaboration::Conflict.new('reason_required', 'Provide a reason for retrying deletion')
    end
  end
end

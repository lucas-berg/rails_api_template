# frozen_string_literal: true

module Platform
  class RetryMail
    def self.call(actor:, delivery:, reason:, request_id:)
      Pundit.authorize(actor, [:admin, delivery], :retry_delivery?)
      raise ArgumentError, 'A reason is required' if reason.blank?

      delivery.with_lock do
        unless delivery.status == 'failed'
          raise Collaboration::Conflict.new('not_retryable', 'Only failed deliveries can be retried')
        end

        delivery.retry_delivery!
        AuditEvent.record!(actor:, action: 'mail_delivery.retried', target: delivery,
                           team: Team.find_by(id: delivery.team_id), reason:, request_id:)
      end
    end
  end
end

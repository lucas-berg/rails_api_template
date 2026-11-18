# frozen_string_literal: true

module Platform
  class RetryNotification
    def initialize(actor:, record:, request_id:)
      @actor = actor
      @delivery = record
      @request_id = request_id
    end

    def call(reason:)
      Pundit.authorize(@actor, [:admin, @delivery], :retry_delivery?)
      raise ArgumentError, 'A reason is required' if reason.blank?

      @delivery.with_lock do
        unless @delivery.status == 'failed'
          raise Collaboration::Conflict.new('not_retryable', 'Only failed deliveries can be retried')
        end

        @delivery.retry_delivery!
        AuditEvent.record!(actor: @actor, action: 'notification_delivery.retried', target: @delivery,
                           team: @delivery.notification.team, reason:, request_id: @request_id)
      end
    end
  end
end

# frozen_string_literal: true

module Platform
  class RetryDispatch
    def initialize(actor:, record:, request_id:)
      @actor = actor
      @record = record
      @request_id = request_id
    end

    def call(reason:)
      raise Authorization::Forbidden unless @actor.is_a?(AdminUser) && @actor.super_admin?
      raise ArgumentError, 'A reason is required' if reason.blank?

      @record.with_lock do
        retry_record
        AuditEvent.record!(actor: @actor, action: "#{@record.model_name.singular}.retried", target: @record,
                           team: team, reason:, request_id: @request_id)
      end
    end

    private

    def retry_record
      case @record
      when NotificationDelivery
        require_status!('failed')
        @record.retry_delivery!
      when Document
        require_status!('purge_failed')
        @record.retry_purge!
      else raise ArgumentError, 'Unsupported retry resource'
      end
    end

    def require_status!(status)
      return if @record.status == status

      raise Collaboration::Conflict.new('not_retryable', 'This operation cannot be retried in its current state')
    end

    def team
      @record.is_a?(Document) ? @record.team : @record.notification.team
    end
  end
end

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
      when NotificationDelivery then @record.retry_delivery!
      else raise ArgumentError, 'Unsupported retry resource'
      end
    end

    def team
      @record.notification.team
    end
  end
end

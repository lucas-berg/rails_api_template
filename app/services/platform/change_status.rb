# frozen_string_literal: true

module Platform
  class ChangeStatus
    def initialize(actor:, target:, request_id:)
      @actor = actor
      @target = target
      @request_id = request_id
    end

    def call(status:, reason:)
      @status = status
      @reason = reason
      validate!
      @target.with_lock do
        validate_lifecycle!
        apply_status
        audit
      end
    end

    private

    def validate!
      raise Authorization::Forbidden unless @actor.is_a?(AdminUser) && @actor.super_admin?
      raise ArgumentError, 'A reason is required' if @reason.blank?
      raise ArgumentError, 'Unsupported status change' unless %w[active suspended].include?(@status)
      raise ArgumentError, 'Unsupported resource' unless [User, Team].include?(@target.class)
    end

    def apply_status
      if @target.is_a?(User)
        @status == 'suspended' ? @target.suspend! : @target.restore!
      else
        @target.update!(status: @status)
      end
    end

    def validate_lifecycle!
      available = @target.is_a?(User) ? @target.restorable? : %w[active suspended].include?(@target.status)
      return if @target.deleted_at.nil? && available

      raise Collaboration::Conflict.new('deletion_in_progress',
                                        'Use the deletion cancellation flow; deleted records cannot be restored')
    end

    def audit
      AuditEvent.record!(actor: @actor, action: "#{@target.model_name.singular}.#{@status}", target: @target,
                         team: @target.is_a?(Team) ? @target : nil, reason: @reason, request_id: @request_id,
                         metadata: { status: @status })
    end
  end
end

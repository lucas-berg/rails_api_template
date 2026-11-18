# frozen_string_literal: true

module Deletions
  class Cancel
    def self.call(actor:, deletion:, password:, request_id: nil)
      new(actor:, deletion:, password:, request_id:).call
    end

    def initialize(actor:, deletion:, password:, request_id: nil)
      @actor = actor
      @deletion = deletion
      @subject = deletion.subject
      @password = password
      @request_id = request_id
    end

    def call
      Lifecycle::MembershipLock.with_user(@actor) do
        verify_actor!
        @subject.with_lock { @deletion.with_lock { cancel } }
      end
    end

    private

    def verify_actor!
      Pundit.authorize(@actor, @deletion, :cancel?)
      return if @actor.valid_password?(@password.to_s)

      raise Pundit::NotAuthorizedError
    end

    def cancel
      return @deletion if @deletion.status == 'canceled'
      unless @deletion.cancellable?
        raise Collaboration::Conflict.new('deletion_started', 'Deletion can no longer be canceled')
      end

      @subject.update!(status: @deletion.previous_team_status) if @subject.is_a?(Team)
      @deletion.update!(status: 'canceled', canceled_at: Time.current, encrypted_recipient: nil)
      notify_and_audit
      @deletion
    end

    def notify_and_audit
      team = @subject if @subject.is_a?(Team)
      AuditEvent.record!(actor: @actor, action: 'deletion.canceled', target: @deletion, team:, request_id: @request_id)
      kind = team ? 'deletion.team_canceled' : 'deletion.account_canceled'
      Notifications::Publish.call(user: @actor, kind:, event_key: "deletion:#{@deletion.uuid}:canceled", team:)
    end
  end
end

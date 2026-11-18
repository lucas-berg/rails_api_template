# frozen_string_literal: true

module Deletions
  class Request
    def self.call(actor:, subject:, password:, request_id: nil)
      new(actor:, subject:, password:, request_id:).call
    end

    def initialize(actor:, subject:, password:, request_id: nil)
      @actor = actor
      @subject = subject
      @password = password
      @request_id = request_id
    end

    def call
      Lifecycle::MembershipLock.with_user(@actor) do
        verify_password!
        @subject.reload
        @subject.is_a?(Team) ? request_team : request_user
      end
    end

    private

    def verify_password!
      return if @actor.active_for_authentication? && @actor.valid_password?(@password.to_s)

      raise Pundit::NotAuthorizedError, 'Confirm your current password'
    end

    def request_team
      @subject.with_lock do
        Pundit.authorize(@actor, @subject, :request_deletion?)
        existing = open_request
        return existing if existing

        previous_status = @subject.status
        unless %w[active suspended].include?(previous_status)
          raise Collaboration::Conflict.new('team_unavailable', 'The team cannot be deleted in its current state')
        end

        record = create_request(previous_team_status: previous_status)
        @subject.update!(status: 'deletion_pending')
        notify(record, 'deletion.team_requested', team: @subject)
        record
      end
    end

    def request_user
      Pundit.authorize(@actor, @subject, :request_deletion?)

      Lifecycle::OwnerGuard.lock_teams(@actor) do
        Lifecycle::OwnerGuard.check!(@actor)
        record = open_request || create_request
        notify(record, 'deletion.account_requested')
        record
      end
    end

    def open_request
      DeletionRequest.find_by(subject: @subject, status: %w[pending processing failed])
    end

    def create_request(**attributes)
      record = DeletionRequest.create!(
        **attributes, subject: @subject, requested_by: @actor,
                      scheduled_at: DeletionRequest.cooling_period.from_now, recipient: @actor.email
      )
      team = @subject if @subject.is_a?(Team)
      AuditEvent.record!(actor: @actor, action: 'deletion.requested', target: record, team:, request_id: @request_id)
      record
    end

    def notify(record, kind, team: nil)
      Notifications::Publish.call(user: @actor, kind:, event_key: "deletion:#{record.uuid}:requested", team:)
    end
  end
end

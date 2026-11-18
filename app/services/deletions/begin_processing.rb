# frozen_string_literal: true

module Deletions
  class BeginProcessing
    def self.call(deletion)
      new(deletion).call
    end

    def initialize(deletion)
      @deletion = deletion
      @subject = deletion.subject
    end

    def call
      users = @subject.is_a?(User) ? [@subject] : []
      started = Lifecycle::MembershipLock.with_users(users) do
        @subject.with_lock { @deletion.with_lock { start_processing! } }
      end
      return false unless started

      # The irreversible decision is committed before external I/O; cancellation is no longer allowed.
      record_tombstone!
      @deletion.update!(stage: 'records') if @deletion.stage == 'ledger'
      true
    end

    private

    def start_processing!
      return if %w[canceled completed].include?(@deletion.status) || @deletion.scheduled_at.future?

      check_owner!
      freeze_subject!
      previous_stage = @deletion.stage
      stage = previous_stage == 'requested' ? 'ledger' : previous_stage
      @deletion.update!(status: 'processing', stage: stage, processing_started_at: Time.current,
                        attempts: @deletion.attempts + 1, failure_code: nil)
      @deletion
    end

    def check_owner!
      return unless @subject.is_a?(User) && @deletion.stage == 'requested'

      Lifecycle::OwnerGuard.lock_teams(@subject) { Lifecycle::OwnerGuard.check!(@subject) }
    end

    def freeze_subject!
      @subject.is_a?(Team) ? @subject.update!(status: 'deleting') : @subject.suspend!
    end

    def record_tombstone!
      tombstone = DeletionTombstone.find_or_create_by!(request_uuid: @deletion.uuid) do |record|
        record.assign_attributes(subject_type: @subject.class.name, subject_id: @subject.id,
                                 fingerprint: DeletionTombstone.fingerprint(@subject), deleted_at: Time.current)
      end
      # Write the independent deletion ledger before any irreversible cleanup.
      Lifecycle::DeletionLedger.write!(tombstone.ledger_entry)
    end
  end
end

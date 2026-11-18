# frozen_string_literal: true

module Lifecycle
  class ReplayDeletions
    def self.call
      ordered_entries.each do |entry|
        subject = DeletionLedger.subject(entry)
        next unless subject

        # A backup may predate ownership transfers; keep the account inaccessible even if manual repair is needed.
        subject.suspend! if subject.is_a?(User) && subject.active?

        replay(entry, subject)
      end
    end

    def self.ordered_entries
      DeletionLedger.entries.sort_by { |entry| entry.fetch('subject_type') == 'Team' ? 0 : 1 }
    end

    def self.replay(entry, subject)
      request = DeletionRequest.find_or_initialize_by(uuid: entry.fetch('request_uuid'))
      request.assign_attributes(subject:, scheduled_at: Time.current, status: 'pending', stage: 'requested',
                                attempts: 0)
      request.save!
      ProcessDeletionJob.perform_now(request.id)
      raise "Deletion replay failed for #{request.uuid}" unless request.reload.status == 'completed'
    end
  end
end

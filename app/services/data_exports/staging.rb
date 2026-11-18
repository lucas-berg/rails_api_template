# frozen_string_literal: true

module DataExports
  module Staging
    # The lease rejects stale workers before allocating any storage object.
    # :reek:ControlParameter
    def self.prepare!(export, lease, io)
      export.with_lock do
        unless export.lease_token == lease
          raise Collaboration::Conflict.new('export_lease_lost',
                                            'Export processing lease expired')
        end

        blob = ActiveStorage::Blob.create_after_unfurling!(io: io, filename: "team-#{export.team_id}-export.json",
                                                           content_type: 'application/json', identify: false)
        export.update!(staging_blob: blob)
        blob
      end
    end

    def self.purge!(export)
      blob = export.reload.staging_blob
      return unless blob
      raise ActiveRecord::RecordNotDestroyed, 'Staging blob is already attached' if blob.attachments.exists?

      blob.delete
      export.with_lock do
        export.update!(staging_blob: nil)
        blob.destroy!
      end
    end
  end
end

# frozen_string_literal: true

module Documents
  class Verify
    def self.call(id)
      document = Document.includes(:team, :uploader).with_attached_file.find_by(id:)
      return unless document&.status == 'processing'

      content_type = InspectContent.call(document)
      finish_verification(document, content_type)
    rescue InspectContent::Invalid => exception
      reject!(id, exception.message)
    rescue ActiveStorage::IntegrityError
      reject!(id, 'file_integrity_mismatch')
    end

    def self.reject!(id, code)
      document = Document.find_by(id:)
      return unless document

      document.with_lock do
        next unless document.status == 'processing'

        document.update!(status: 'rejected', failure_code: code, purge_requested_at: Time.current)
      end
    end

    def self.eligible?(document)
      team = document.team
      available = document.upload_expires_at.future? && team.active?
      available && document.uploader.reload.active_for_authentication? &&
        team.active_members.where(user_id: document.uploader_id).where.not(role: 'viewer').exists?
    end

    def self.finish_verification(document, content_type)
      document.team.with_lock do
        document.with_lock do
          next unless document.status == 'processing'

          now = Time.current
          if eligible?(document)
            document.update!(status: 'ready', verified_content_type: content_type, verified_at: now,
                             last_error: nil)
          else
            document.update!(status: 'rejected', failure_code: 'upload_unavailable', purge_requested_at: now)
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Documents
  class Complete < Collaboration::Operation
    def call(id)
      within_team do
        document = Document.where(team:).with_attached_file.find(id)
        authorize!(:complete, document)
        return document if %w[processing ready].include?(document.status)

        check_upload!(document)
        document.update!(status: 'processing', verification_requested_at: Time.current)
        audit!('file.completed', document)
        document
      end
    end

    private

    # :reek:FeatureEnvy -- This service validates a record's transition before scheduling verification.
    def check_upload!(document)
      unless document.status == 'uploading' && document.file.attached?
        raise Collaboration::Conflict.new('upload_unavailable', 'This upload cannot be completed')
      end
      return if document.upload_expires_at.future?

      raise Collaboration::Conflict.new('upload_expired', 'This upload has expired')
    end
  end
end

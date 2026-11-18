# frozen_string_literal: true

module Documents
  # :reek:FeatureEnvy -- The upload boundary reads untrusted multipart metadata before persisting it.
  class Upload < Collaboration::Operation
    def call(file:)
      validate_upload!(file)
      within_team do
        document = build_document(file)
        authorize!(:create, document)
        document.file.attach(file)
        document.save!
        audit!('file.uploaded', document)
        document
      end
    end

    private

    def build_document(file)
      Document.new(team:, uploader: actor, original_filename: file.original_filename,
                   declared_content_type: file.content_type, byte_size: file.size,
                   upload_expires_at: 1.hour.from_now)
    end

    def validate_upload!(file)
      unless file.is_a?(ActionDispatch::Http::UploadedFile)
        raise ActionController::BadRequest, 'file must be a multipart upload; signed IDs are not accepted'
      end

      size = file.size
      return if size.positive? && size <= Document.maximum_bytes && Document::CONTENT_TYPES.include?(file.content_type)

      raise Collaboration::Conflict.new('invalid_upload', 'Upload a PNG, JPEG or PDF within the file size limit')
    end
  end
end

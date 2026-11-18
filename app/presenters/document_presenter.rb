# frozen_string_literal: true

module DocumentPresenter
  def self.call(document)
    { id: document.id, team_id: document.team_id, uploader_id: document.uploader_id,
      filename: document.original_filename, byte_size: document.byte_size, status: document.status,
      content_type: document.verified_content_type, failure_code: document.failure_code,
      upload_expires_at: document.upload_expires_at.iso8601, verified_at: document.verified_at&.iso8601,
      created_at: document.created_at.iso8601 }
  end
end

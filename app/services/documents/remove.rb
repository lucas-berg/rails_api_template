# frozen_string_literal: true

module Documents
  class Remove < Collaboration::Operation
    def call(id)
      within_team do
        document = Document.where(team:).find(id)
        authorize!(:remove, document)
        return document if %w[deleting deleted].include?(document.status)

        document.with_lock do
          clear_avatars(document)
          document.update!(status: 'deleting', purge_requested_at: Time.current, purge_attempts: 0)
          audit!('file.deleted', document)
        end
        document
      end
    end

    private

    def clear_avatars(document)
      User.where(avatar_document_id: document.id).find_each { |user| user.update!(avatar_document_id: nil) }
    end
  end
end

# frozen_string_literal: true

module Documents
  class AssignAvatar < Collaboration::Operation
    def call(document_id)
      within_team do
        document = Document.where(team:).find(document_id)
        authorize!(:avatar, document)
        document.with_lock do
          unless document.ready? && document.image?
            raise Collaboration::Conflict.new('avatar_unavailable', 'Choose a verified PNG or JPEG upload')
          end

          actor.update!(avatar_document_id: document.id)
          audit!('avatar.updated', document)
        end
        document
      end
    end

    def clear
      within_team do
        document = Document.where(team:).find(actor.avatar_document_id)
        authorize!(:avatar, document)
        actor.update!(avatar_document_id: nil)
        audit!('avatar.removed', document)
      end
    end
  end
end

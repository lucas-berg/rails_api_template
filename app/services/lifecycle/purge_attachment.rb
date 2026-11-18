# frozen_string_literal: true

module Lifecycle
  class PurgeAttachment
    def self.call(attachment)
      return unless attachment.attached?

      blob = attachment.blob
      raise ActiveRecord::RecordNotDestroyed, 'Shared blob cannot be purged' if blob.attachments.count > 1

      blob.delete
      ApplicationRecord.transaction do
        attachment.attachment.destroy!
        blob.destroy!
      end
    end
  end
end

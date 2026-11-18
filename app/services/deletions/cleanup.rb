# frozen_string_literal: true

module Deletions
  class Cleanup
    def initialize(deletion)
      @deletion = deletion
      @subject = deletion.subject
      @subject_id = @subject.id
      @scope_key = :team_id if @subject.is_a?(Team)
    end

    def call
      purge_files
      purge_exports
      ApplicationRecord.transaction do
        remove_notifications
        remove_invites_and_mail
        remove_memberships
        anonymize_subject
        audit_completion
        @deletion.update!(stage: 'completed', status: 'completed', completed_at: Time.current, failure_code: nil)
      end
    end

    private

    def scoped(model, user_column)
      model.where(@scope_key || user_column => @subject_id)
    end

    def purge_files
      documents = scoped(Document, :uploader_id)
      documents.find_each { |document| purge_document!(document) }
      documents.delete_all
      @deletion.update!(stage: 'exports')
    end

    # The cleanup service coordinates the file record with its storage deletion worker.
    # :reek:FeatureEnvy
    def purge_document!(document)
      return if document.purged_at

      document_id = document.id
      document.with_lock do
        # Clearing a file reference must not send new profile notifications.
        # rubocop:disable-next Rails/SkipsModelValidations
        User.where(avatar_document_id: document_id).update_all(avatar_document_id: nil)
        document.update!(status: 'deleting', purge_requested_at: Time.current, purge_attempts: 0)
      end
      PurgeDocumentJob.perform_now(document_id)
      raise IOError, 'Document purge incomplete' unless document.reload.purged_at
    end

    # :reek:FeatureEnvy
    def purge_exports
      scoped(DataExport, :requested_by_id).find_each do |export|
        completed = Lifecycle::ExecutionLock.with(namespace: 72_127, id: export.id) do
          export.with_lock { export.update!(status: 'expired', lease_token: nil, expires_at: Time.current) }
          Lifecycle::PurgeAttachment.call(export.file)
          DataExports::Staging.purge!(export)
          export.destroy!
          true
        end
        raise IOError, 'An export is still processing; retry cleanup later' unless completed
      end
      @deletion.update!(stage: 'records')
    end

    def remove_notifications
      notifications = scoped(Notification, :user_id)
      NotificationDelivery.where(notification_id: notifications.select(:id)).delete_all
      notifications.delete_all
      NotificationPreference.where(user_id: @subject.id).delete_all if @subject.is_a?(User)
    end

    def remove_invites_and_mail
      invitations = scoped(Invitation, :invited_by_id)
      if @subject.is_a?(User)
        invitations = invitations.or(Invitation.where(normalized_email: @subject.email))
        clear_invitation_mail(invitations)
      end
      invitations.delete_all
      scoped(MailDelivery, :user_id).delete_all
    end

    def clear_invitation_mail(invitations)
      ids = invitations.pluck(:id)
      MailDelivery.where(kind: 'invitation', team_id: invitations.select(:team_id)).find_each do |delivery|
        delivery.destroy! if ids.include?(delivery.payload['invitation_id'])
      end
    end

    def remove_memberships
      scoped(Member, :user_id).delete_all
      return unless @subject.is_a?(User)

      AuthSession.where(user_id: @subject.id).delete_all
    end

    def anonymize_subject
      @scope_key ? anonymize_team : anonymize_user
      filters = @scope_key ? { team_id: @subject_id } : { actor_type: 'User', actor_id: @subject_id }
      events = AuditEvent.where(filters)
      # Retained audit identifiers remain useful; personal metadata and reasons are erased.
      # rubocop:disable-next Rails/SkipsModelValidations
      events.update_all(metadata: {}, reason: nil)
    end

    def audit_completion
      team = @subject if @subject.is_a?(Team)
      recipient = @deletion.requested_by
      actor = recipient || Lifecycle::SystemActor.new
      AuditEvent.record!(actor: actor, action: 'deletion.completed', target: @subject, team: team)
      return unless team && recipient

      Notifications::Publish.call(user: recipient, kind: 'deletion.team_completed',
                                  event_key: "deletion:#{@deletion.uuid}:completed")
    end

    def anonymize_team
      @subject.update!(name: 'Deleted team', slug: "deleted-team-#{@subject.id}", timezone: 'UTC', locale: 'en',
                       status: 'deleted', deleted_at: @subject.deleted_at || Time.current)
    end

    def anonymize_user
      # Controlled anonymization bypasses reconfirmation and security mail callbacks after cleanup.
      # rubocop:disable-next Rails/SkipsModelValidations
      @subject.update_columns(anonymized_attributes)
    end

    def anonymized_attributes
      now = Time.current
      {
        email: "deleted-#{@subject_id}@deleted.invalid", uid: "deleted-#{@subject_id}",
        first_name: '', last_name: '', username: '', provider: 'email', tokens: nil,
        encrypted_password: Devise::Encryptor.digest(User, SecureRandom.hex(32)),
        status: 'suspended', credentials_version: @subject.credentials_version + 1,
        confirmation_token: nil, confirmed_at: nil, confirmation_sent_at: nil,
        unconfirmed_email: nil, reset_password_token: nil, reset_password_sent_at: nil,
        current_sign_in_ip: nil, last_sign_in_ip: nil, sign_in_count: 0,
        current_sign_in_at: nil, last_sign_in_at: nil, preferences: {}, avatar_document_id: nil,
        deleted_at: @subject.deleted_at || now, updated_at: now
      }
    end
  end
end

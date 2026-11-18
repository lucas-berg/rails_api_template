# frozen_string_literal: true

module UserAuthentication
  extend ActiveSupport::Concern

  included do
    has_many :auth_sessions, dependent: :restrict_with_error

    enum :status, { active: 'active', suspended: 'suspended' }, validate: true
    validates :credentials_version, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    # Persist mail intent before commit, so mail failure cannot leave an unnotified account change.
    skip_callback :commit, :after, :send_on_create_confirmation_instructions
    skip_callback :commit, :after, :send_reconfirmation_instructions
    after_create :send_on_create_confirmation_instructions, if: :send_confirmation_notification?
    after_update :send_reconfirmation_instructions, if: :reconfirmation_required?
    before_update :advance_credentials_version, if: :credentials_changed?
    after_update :revoke_auth_sessions, if: :saved_change_to_credentials_version?
    after_update :publish_security_notifications
  end

  class_methods do
    def reset_password_by_token(attributes = {})
      transaction do
        token = attributes[:reset_password_token]
        digest = Devise.token_generator.digest(self, :reset_password_token, token) if token.present?
        where(reset_password_token: digest).lock.load if digest
        super
      end
    end

    def confirm_by_token(token)
      transaction do
        where(confirmation_token: token).lock.load if token.present?
        super
      end
    end
  end

  def jwt_payload
    { 'credentials_version' => credentials_version }
  end

  def suspend!
    update!(status: 'suspended')
  end

  def restore!
    update!(status: 'active')
  end

  def active_for_authentication?
    super && active?
  end

  def inactive_message
    suspended? ? :suspended : super
  end

  def authenticatable_salt
    "#{super}:#{credentials_version}"
  end

  def send_confirmation_instructions
    self.class.transaction { super }
  end

  def send_reset_password_instructions
    self.class.transaction { super }
  end

  protected

  def send_devise_notification(notification, *args)
    MailDelivery.enqueue_devise(self, notification, args)
  end

  private

  def credentials_changed?
    will_save_change_to_encrypted_password? || (will_save_change_to_status? && suspended?)
  end

  def advance_credentials_version
    self.credentials_version = self.class.where(id: id).lock.pick(:credentials_version) + 1
  end

  def revoke_auth_sessions
    revoked_at = Time.current
    # Bulk revocation is atomic with the credential change and requires no session callbacks.
    # rubocop:disable-next Rails/SkipsModelValidations
    auth_sessions.where(revoked_at: nil).update_all(revoked_at: revoked_at, updated_at: revoked_at)
  end

  def publish_security_notifications
    return if has_attribute?(:deleted_at) && self[:deleted_at].present?

    publish_security_notification('password_changed') if saved_change_to_encrypted_password?
    return unless saved_change_to_status?

    publish_security_notification(suspended? ? 'account_suspended' : 'account_restored')
  end

  def publish_security_notification(kind)
    Notifications::Publish.call(user: self, kind:, event_key: "user:#{id}:#{kind}:#{credentials_version}")
  end
end

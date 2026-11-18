# frozen_string_literal: true

# == Schema Information
#
# Table name: mail_deliveries
#
#  id                :bigint           not null, primary key
#  attempts          :integer          default(0), not null
#  encrypted_payload :text
#  event_key         :string           not null
#  kind              :string           not null
#  last_error        :string
#  lease_token       :string
#  locked_at         :datetime
#  next_attempt_at   :datetime         not null
#  sent_at           :datetime
#  status            :string           default("pending"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  team_id           :bigint
#  user_id           :integer
#
# Indexes
#
#  index_mail_deliveries_on_event_key                   (event_key) UNIQUE
#  index_mail_deliveries_on_status_and_locked_at        (status,locked_at)
#  index_mail_deliveries_on_status_and_next_attempt_at  (status,next_attempt_at)
#  index_mail_deliveries_on_team_id                     (team_id)
#  index_mail_deliveries_on_user_id                     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => nullify
#
class MailDelivery < ApplicationRecord
  DEVISE_NOTIFICATIONS = %w[confirmation_instructions reset_password_instructions unlock_instructions
                            password_change email_changed].freeze
  LEASE_DURATION = 5.minutes
  MAX_ATTEMPTS = 8
  RANSACK_ATTRIBUTES = %w[id user_id team_id kind status attempts next_attempt_at sent_at last_error created_at].freeze

  belongs_to :user, optional: true

  validates :kind, inclusion: { in: %w[devise invitation] }
  validates :status, inclusion: { in: %w[pending sending sent failed skipped] }
  validates :event_key, :next_attempt_at, presence: true

  after_create_commit :enqueue_delivery

  scope :due, lambda {
    where(status: 'pending', next_attempt_at: ..Time.current)
      .or(where(status: 'sending', locked_at: ..LEASE_DURATION.ago))
  }

  def self.enqueue_devise(user, notification, args = [], event_key: SecureRandom.uuid)
    notification = notification.to_s
    raise ArgumentError, 'Unsupported account notification' unless DEVISE_NOTIFICATIONS.include?(notification)

    user_id = user.id
    # A deliberate resend is a new event, even when Devise reuses a still-valid confirmation token.
    key = Digest::SHA256.hexdigest("devise:#{user_id}:#{notification}:#{event_key}")
    enqueue_once(key, kind: 'devise', user_id:, payload: { notification:, args: })
  end

  def self.enqueue_invitation(invitation, token)
    invitation_id = invitation.id
    key = Digest::SHA256.hexdigest("invitation:#{invitation_id}:#{token}")
    enqueue_once(key, kind: 'invitation', user_id: invitation.invited_by_id, team_id: invitation.team_id,
                      payload: { invitation_id:, token: })
  end

  def self.enqueue_once(key, payload:, **attributes)
    create_or_find_by!(event_key: key) do |delivery|
      delivery.assign_attributes(attributes)
      delivery.next_attempt_at = Time.current
      delivery.payload = payload
    end
  end

  def self.encryptor
    key = Rails.application.key_generator.generate_key('mail-delivery-payload-v1', 32)
    ActiveSupport::MessageEncryptor.new(key, cipher: 'aes-256-gcm', serializer: JSON)
  end

  def payload=(value)
    self.encrypted_payload = self.class.encryptor.encrypt_and_sign(value, purpose: 'transactional-mail')
  end

  def payload
    return {} if encrypted_payload.blank?

    self.class.encryptor.decrypt_and_verify(encrypted_payload, purpose: 'transactional-mail') || {}
  end

  def claim!
    with_lock do
      return unless claimable?

      if attempts >= MAX_ATTEMPTS
        update!(status: 'failed', locked_at: nil, lease_token: nil, last_error: 'DeliveryLeaseExpired')
        return
      end

      update!(status: 'sending', locked_at: Time.current, lease_token: SecureRandom.uuid, attempts: attempts + 1)
      lease_token
    end
  end

  def finish!(lease, status: 'sent')
    with_lock do
      return unless owns_lease?(lease)

      update!(status:, sent_at: (Time.current if status == 'sent'), encrypted_payload: nil,
              locked_at: nil, lease_token: nil, last_error: nil)
    end
  end

  def fail!(lease, exception)
    with_lock do
      return unless owns_lease?(lease)

      update!(status: attempts >= MAX_ATTEMPTS ? 'failed' : 'pending', locked_at: nil, lease_token: nil,
              next_attempt_at: (2**attempts).minutes.from_now, last_error: exception.class.name)
    end
  end

  def retry_delivery!
    with_lock do
      raise ArgumentError, 'Only failed deliveries can be retried' unless status == 'failed'

      update!(status: 'pending', attempts: 0, next_attempt_at: Time.current, last_error: nil)
    end
    enqueue_delivery
  end

  private

  def owns_lease?(lease)
    status == 'sending' && lease_token == lease
  end

  def claimable?
    (status == 'pending' && next_attempt_at <= Time.current) ||
      (status == 'sending' && locked_at.present? && locked_at <= LEASE_DURATION.ago)
  end

  def enqueue_delivery
    SendMailDeliveryJob.perform_later(id)
  rescue StandardError => exception
    # The committed outbox row is recovered by the periodic sweep even if the queue is unavailable.
    Rails.logger.error("Mail delivery enqueue failed id=#{id} error=#{exception.class.name}")
  end
end

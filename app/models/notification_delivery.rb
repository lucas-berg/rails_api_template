# frozen_string_literal: true

class NotificationDelivery < ApplicationRecord
  LEASE_DURATION = 5.minutes
  MAX_ATTEMPTS = 8

  belongs_to :notification

  validates :channel, inclusion: { in: %w[in_app email] }, uniqueness: { scope: :notification_id }
  validates :status, inclusion: { in: %w[pending sending sent failed skipped] }
  validates :attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :next_attempt_at, presence: true

  after_create_commit :enqueue_delivery, if: -> { channel == 'email' && status == 'pending' }

  scope :due, lambda {
    where(channel: 'email').where(status: 'pending', next_attempt_at: ..Time.current)
                           .or(where(channel: 'email', status: 'sending', locked_at: ..LEASE_DURATION.ago))
  }

  def claim!
    with_lock do
      return unless claimable?

      if attempts >= MAX_ATTEMPTS
        update!(status: 'failed', locked_at: nil, lease_token: nil, last_error: 'DeliveryLeaseExpired')
        return
      end

      update!(status: 'sending', attempts: attempts + 1, locked_at: Time.current, lease_token: SecureRandom.uuid)
      lease_token
    end
  end

  def finish!(lease, status: 'sent')
    with_lock do
      return unless owns_lease?(lease)

      update!(status:, sent_at: (Time.current if status == 'sent'), locked_at: nil, lease_token: nil, last_error: nil)
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
    return false unless channel == 'email'

    (status == 'pending' && next_attempt_at <= Time.current) ||
      (status == 'sending' && locked_at.present? && locked_at <= LEASE_DURATION.ago)
  end

  def enqueue_delivery
    SendNotificationDeliveryJob.perform_later(id)
  rescue StandardError => exception
    Rails.logger.error("Notification enqueue failed id=#{id} error=#{exception.class.name}")
  end
end

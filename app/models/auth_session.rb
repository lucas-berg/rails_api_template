# frozen_string_literal: true

class AuthSession < ApplicationRecord
  class InvalidCredentials < StandardError; end

  RANSACK_ATTRIBUTES = %w[id user_id expires_at revoked_at last_used_at created_at].freeze

  belongs_to :user

  validates :jti_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :credentials_version, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(revoked_at: nil).where('expires_at > ?', Time.current) }

  def self.register!(user, payload)
    transaction do
      identity = User.lock.find(user.id)
      raise InvalidCredentials unless current_credentials?(identity, payload)

      create!(user: identity, jti_digest: digest(payload.fetch('jti')),
              credentials_version: identity.credentials_version,
              expires_at: Time.zone.at(payload.fetch('exp')), last_used_at: Time.current)
    end
  end

  def self.jwt_revoked?(payload, user)
    return true unless current_credentials?(user, payload)

    session = user.auth_sessions.find_by(jti_digest: digest(payload['jti']))
    return true unless session&.valid_for?(user)

    session.touch_usage
    false
  end

  def self.revoke_jwt(payload, user)
    user.auth_sessions.find_by(jti_digest: digest(payload['jti']))&.revoke!
  end

  def self.digest(jti)
    Digest::SHA256.hexdigest(jti.to_s)
  end

  def self.current_credentials?(identity, payload)
    identity.active_for_authentication? && payload['credentials_version'] == identity.credentials_version
  end

  def valid_for?(identity)
    revoked_at.nil? && expires_at > Time.current && credentials_version == identity.credentials_version
  end

  def revoke!
    update!(revoked_at: Time.current) unless revoked_at?
  end

  def touch_usage
    update!(last_used_at: Time.current) if last_used_at.nil? || last_used_at < 1.minute.ago
  end
end

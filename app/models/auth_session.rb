# frozen_string_literal: true

# == Schema Information
#
# Table name: auth_sessions
#
#  id                  :bigint           not null, primary key
#  credentials_version :integer          not null
#  expires_at          :datetime         not null
#  ip_address          :inet
#  jti_digest          :string           not null
#  last_used_at        :datetime
#  revoked_at          :datetime
#  user_agent          :string(256)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  user_id             :integer          not null
#
# Indexes
#
#  index_auth_sessions_on_expires_at  (expires_at)
#  index_auth_sessions_on_jti_digest  (jti_digest) UNIQUE
#  index_auth_sessions_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class AuthSession < ApplicationRecord
  class InvalidCredentials < StandardError; end

  CONTROL_CHARACTERS = /[[:cntrl:]\p{Cf}]/
  RANSACK_ATTRIBUTES = %w[id user_id expires_at revoked_at last_used_at created_at].freeze

  belongs_to :user

  validates :jti_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :credentials_version, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :user_agent, length: { maximum: 256 }, format: { without: CONTROL_CHARACTERS }, allow_nil: true

  scope :active, -> { where(revoked_at: nil).where('expires_at > ?', Time.current) }

  def self.register!(user, payload, context: {})
    transaction do
      identity = User.lock.find(user.id)
      raise InvalidCredentials unless current_credentials?(identity, payload)

      create_registration!(identity, payload, context)
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

  def self.create_registration!(identity, payload, context)
    create!(user: identity, jti_digest: digest(payload.fetch('jti')),
            credentials_version: identity.credentials_version,
            expires_at: Time.zone.at(payload.fetch('exp')), last_used_at: Time.current, **client_metadata(context))
  end

  def self.client_metadata(context)
    attributes = context.to_h
    { user_agent: sanitize_agent(attributes[:user_agent]), ip_address: sanitize_ip(attributes[:ip_address]) }
  end

  def self.sanitize_agent(value)
    value.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
         .gsub(CONTROL_CHARACTERS, '')[0, 256].presence
  end

  def self.sanitize_ip(value)
    IPAddr.new(value.to_s).to_s if value.present?
  rescue IPAddr::InvalidAddressError
    nil
  end

  private_class_method :create_registration!, :client_metadata, :sanitize_agent, :sanitize_ip
end

# frozen_string_literal: true

class Invitation < ApplicationRecord
  belongs_to :team
  belongs_to :invited_by, class_name: 'User'

  enum :role, { admin: 'admin', member: 'member', viewer: 'viewer' }, validate: true

  before_validation :normalize_email

  validates :normalized_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  RANSACK_ATTRIBUTES = %w[id team_id invited_by_id normalized_email role expires_at accepted_at revoked_at
                          created_at].freeze

  def pending?
    accepted_at.nil? && revoked_at.nil? && expires_at.future?
  end

  def token_matches?(token)
    ActiveSupport::SecurityUtils.secure_compare(token_digest, Digest::SHA256.hexdigest(token.to_s))
  end

  private

  def normalize_email
    self.normalized_email = normalized_email.to_s.strip.downcase
  end
end

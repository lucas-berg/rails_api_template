# frozen_string_literal: true

# == Schema Information
#
# Table name: invitations
#
#  id               :bigint           not null, primary key
#  accepted_at      :datetime
#  expires_at       :datetime         not null
#  normalized_email :string           not null
#  revoked_at       :datetime
#  role             :string           default("member"), not null
#  token_digest     :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  invited_by_id    :integer          not null
#  team_id          :bigint           not null
#
# Indexes
#
#  index_invitations_on_invited_by_id  (invited_by_id)
#  index_invitations_on_pending_email  (team_id,normalized_email) UNIQUE WHERE ((accepted_at IS NULL) AND (revoked_at IS NULL))
#  index_invitations_on_team_id        (team_id)
#  index_invitations_on_token_digest   (token_digest) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (invited_by_id => users.id)
#  fk_rails_...  (team_id => teams.id)
#
class Invitation < ApplicationRecord
  delegate :name, to: :team, prefix: true

  belongs_to :team
  belongs_to :invited_by, class_name: 'User'

  enum :role, { admin: 'admin', member: 'member', viewer: 'viewer' }, validate: true

  before_validation :normalize_email

  validates :normalized_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[team_id normalized_email role]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

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

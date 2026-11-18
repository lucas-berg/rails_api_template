# frozen_string_literal: true

# == Schema Information
#
# Table name: teams
#
#  id         :bigint           not null, primary key
#  deleted_at :datetime
#  locale     :string           default("en"), not null
#  name       :string           not null
#  slug       :string           not null
#  status     :string           default("active"), not null
#  timezone   :string           default("UTC"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_teams_on_slug  (slug) UNIQUE
#
class Team < ApplicationRecord
  LOCALES = %w[en zh-CN].freeze
  ACCESSIBLE_STATUSES = %w[active suspended deletion_pending].freeze

  has_many :members, dependent: :restrict_with_error
  has_many :active_members, -> { active }, class_name: 'Member', dependent: :restrict_with_error, inverse_of: :team
  has_many :users, through: :active_members
  has_many :invitations, dependent: :restrict_with_error
  has_many :audit_events, dependent: :restrict_with_error
  has_many :documents, dependent: :restrict_with_error
  has_many :notifications, dependent: :restrict_with_error

  enum :status, { active: 'active', suspended: 'suspended', deletion_pending: 'deletion_pending',
                  deleting: 'deleting', deleted: 'deleted' }, validate: true

  before_validation :assign_slug, on: :create

  validates :name, presence: true, length: { maximum: 100 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :locale, inclusion: { in: LOCALES }
  validate :valid_timezone

  RANSACK_ATTRIBUTES = %w[id name slug status timezone locale created_at updated_at].freeze

  scope :accessible, -> { where(status: ACCESSIBLE_STATUSES) }

  def accessible?
    ACCESSIBLE_STATUSES.include?(status)
  end

  def flipper_id
    "Team;#{id}"
  end

  private

  def assign_slug
    self.slug ||= "#{name.to_s.parameterize.presence || 'team'}-#{SecureRandom.hex(4)}"
  end

  def valid_timezone
    errors.add(:timezone, 'is not a valid timezone') unless timezone.is_a?(String) && ActiveSupport::TimeZone[timezone]
  end
end

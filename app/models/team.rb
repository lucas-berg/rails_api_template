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
  ACCESSIBLE_STATUSES = %w[active suspended].freeze

  has_many :members, dependent: :restrict_with_error
  has_many :active_members, -> { active }, class_name: 'Member', dependent: :restrict_with_error, inverse_of: :team
  has_many :users, through: :active_members
  has_many :invitations, dependent: :restrict_with_error
  has_many :audit_events, dependent: :restrict_with_error
  has_many :notifications, dependent: :restrict_with_error

  enum :status, { active: 'active', suspended: 'suspended', deleted: 'deleted' }, validate: true

  before_validation :assign_slug, on: :create

  validates :name, presence: true, length: { maximum: 100 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :locale, inclusion: { in: LOCALES }
  validate :valid_timezone
  validate :deleted_teams_stay_deleted

  scope :accessible, -> { where(status: ACCESSIBLE_STATUSES, deleted_at: nil) }

  def self.ransackable_attributes(_auth_object = nil)
    %w[id name status]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  def accessible?
    deleted_at.nil? && ACCESSIBLE_STATUSES.include?(status)
  end

  def flipper_id
    "Team;#{id}"
  end

  private

  def deleted_teams_stay_deleted
    return if deleted? || (deleted_at.nil? && status_in_database != 'deleted')

    errors.add(:status, 'cannot reactivate a deleted team')
  end

  def assign_slug
    self.slug ||= "#{name.to_s.parameterize.presence || 'team'}-#{SecureRandom.hex(4)}"
  end

  def valid_timezone
    errors.add(:timezone, 'is not a valid timezone') unless timezone.is_a?(String) && ActiveSupport::TimeZone[timezone]
  end
end

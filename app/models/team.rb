# frozen_string_literal: true

class Team < ApplicationRecord
  LOCALES = %w[en zh-CN].freeze

  has_many :members, dependent: :restrict_with_error
  has_many :active_members, -> { active }, class_name: 'Member', dependent: :restrict_with_error, inverse_of: :team
  has_many :users, through: :active_members
  has_many :invitations, dependent: :restrict_with_error
  has_many :audit_events, dependent: :restrict_with_error
  has_many :notifications, dependent: :restrict_with_error

  enum :status, { active: 'active', suspended: 'suspended' }, validate: true

  before_validation :assign_slug, on: :create

  validates :name, presence: true, length: { maximum: 100 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :locale, inclusion: { in: LOCALES }
  validate :valid_timezone

  RANSACK_ATTRIBUTES = %w[id name slug status timezone locale created_at updated_at].freeze

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

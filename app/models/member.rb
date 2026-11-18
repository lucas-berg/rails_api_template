# frozen_string_literal: true

class Member < ApplicationRecord
  belongs_to :team
  belongs_to :user

  enum :role, { owner: 'owner', admin: 'admin', member: 'member', viewer: 'viewer' }, validate: true
  enum :status, { active: 'active', removed: 'removed' }, validate: true

  validates :user_id, uniqueness: { scope: :team_id }

  RANSACK_ATTRIBUTES = %w[id team_id user_id role status created_at updated_at].freeze
end

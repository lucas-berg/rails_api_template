# frozen_string_literal: true

# == Schema Information
#
# Table name: members
#
#  id         :bigint           not null, primary key
#  role       :string           default("member"), not null
#  status     :string           default("active"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  team_id    :bigint           not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_members_on_team_id              (team_id)
#  index_members_on_team_id_and_user_id  (team_id,user_id) UNIQUE
#  index_members_on_user_id              (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id)
#  fk_rails_...  (user_id => users.id)
#
class Member < ApplicationRecord
  belongs_to :team
  belongs_to :user

  enum :role, { owner: 'owner', admin: 'admin', member: 'member', viewer: 'viewer' }, validate: true
  enum :status, { active: 'active', removed: 'removed' }, validate: true

  validates :user_id, uniqueness: { scope: :team_id }

  def self.ransackable_attributes(_auth_object = nil)
    %w[team_id user_id role status]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end

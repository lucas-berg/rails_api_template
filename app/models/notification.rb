# frozen_string_literal: true

# == Schema Information
#
# Table name: notifications
#
#  id         :bigint           not null, primary key
#  category   :string           not null
#  event_key  :string           not null
#  kind       :string           not null
#  read_at    :datetime
#  visible_at :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  team_id    :bigint
#  user_id    :integer          not null
#
# Indexes
#
#  index_notifications_on_team_id                             (team_id)
#  index_notifications_on_user_id                             (user_id)
#  index_notifications_on_user_id_and_event_key               (user_id,event_key) UNIQUE
#  index_notifications_on_user_id_and_team_id_and_created_at  (user_id,team_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id)
#  fk_rails_...  (user_id => users.id)
#
class Notification < ApplicationRecord
  delegate :email, to: :user, prefix: true

  belongs_to :user
  belongs_to :team, optional: true
  has_many :notification_deliveries, dependent: :delete_all

  validates :event_key, presence: true, length: { maximum: 200 }
  validates :kind, inclusion: { in: Notifications::Catalog::EVENTS.keys }
  validates :category, inclusion: { in: %w[security activity] }
  validate :category_matches_event

  scope :visible, -> { where.not(visible_at: nil) }

  def self.ransackable_attributes(_auth_object = nil)
    %w[user_id team_id kind category]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  def self.visible_to(user)
    return none unless user.active_for_authentication?

    scope = visible.where(user_id: user.id)
    scope.where(team_id: nil).or(scope.where(team_id: user.active_members.select(:team_id)))
  end

  def readable_by?(actor)
    actor.id == user_id && self.class.visible_to(actor).exists?(id: id)
  end

  def deliverable?
    return true if category == 'security'

    user.active_for_authentication? && team_allows_delivery? && team.active_members.exists?(user_id: user_id)
  end

  def mark_read!
    with_lock { update!(read_at: Time.current) unless read_at? }
  end

  def presentation
    attributes.slice('id', 'kind', 'category', 'team_id', 'read_at', 'created_at')
              .merge(localized_content)
  end

  def localized_content
    Notifications::Catalog.text(kind, user:, team:)
  end

  private

  def team_allows_delivery?
    statuses = if %w[deletion.team_requested deletion.team_canceled].include?(kind)
                 %w[active suspended deletion_pending]
               else
                 %w[active]
               end
    statuses.include?(team.status)
  end

  def category_matches_event
    return unless Notifications::Catalog::EVENTS.key?(kind)

    errors.add(:category, 'does not match this event') unless category == Notifications::Catalog.category(kind)
    return unless (category == 'activity') != team_id.present?

    errors.add(:team,
               'must be present for activity and absent for security')
  end
end

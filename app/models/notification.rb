# frozen_string_literal: true

class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :team, optional: true
  has_many :notification_deliveries, dependent: :delete_all

  validates :event_key, presence: true, length: { maximum: 200 }
  validates :kind, inclusion: { in: Notifications::Catalog::EVENTS.keys }
  validates :category, inclusion: { in: %w[security activity] }
  validate :category_matches_event

  scope :visible, -> { where.not(visible_at: nil) }

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
              .merge(Notifications::Catalog.text(kind))
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

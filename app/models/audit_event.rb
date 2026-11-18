# frozen_string_literal: true

# == Schema Information
#
# Table name: audit_events
#
#  id          :bigint           not null, primary key
#  action      :string           not null
#  actor_type  :string           not null
#  metadata    :jsonb            not null
#  occurred_at :datetime         not null
#  reason      :string
#  target_type :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  actor_id    :bigint
#  request_id  :string
#  target_id   :bigint
#  team_id     :bigint
#
# Indexes
#
#  index_audit_events_on_actor_type_and_actor_id         (actor_type,actor_id)
#  index_audit_events_on_target_type_and_target_id       (target_type,target_id)
#  index_audit_events_on_team_id                         (team_id)
#  index_audit_events_on_team_id_and_occurred_at_and_id  (team_id,occurred_at,id)
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id)
#
class AuditEvent < ApplicationRecord
  belongs_to :team, optional: true

  validates :actor_type, :action, :target_type, :occurred_at, presence: true

  SAFE_METADATA = %w[name locale timezone status role previous_role member_id previous_owner_id new_owner_id].freeze

  def self.ransackable_attributes(_auth_object = nil)
    %w[team_id actor_type actor_id action target_type target_id occurred_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  def self.record!(actor:, action:, target:, **context)
    create!(
      **context.slice(:team, :request_id, :reason),
      actor_type: actor.class.name, actor_id: actor.id, action:,
      target_type: target.class.name, target_id: target.id, occurred_at: Time.current,
      metadata: context.fetch(:metadata, {}).stringify_keys.slice(*SAFE_METADATA)
    )
  end
end

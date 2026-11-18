# frozen_string_literal: true

class AuditEvent < ApplicationRecord
  belongs_to :team, optional: true

  validates :actor_type, :action, :target_type, :occurred_at, presence: true

  RANSACK_ATTRIBUTES = %w[id team_id actor_type actor_id action target_type target_id request_id reason
                          occurred_at].freeze
  SAFE_METADATA = %w[name locale timezone status role previous_role member_id previous_owner_id new_owner_id].freeze

  def self.record!(actor:, action:, target:, **context)
    create!(
      **context.slice(:team, :request_id, :reason),
      actor_type: actor.class.name, actor_id: actor.id, action:,
      target_type: target.class.name, target_id: target.id, occurred_at: Time.current,
      metadata: context.fetch(:metadata, {}).stringify_keys.slice(*SAFE_METADATA)
    )
  end
end

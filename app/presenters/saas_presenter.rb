# frozen_string_literal: true

module SaasPresenter
  def self.team(record)
    record.attributes.slice('id', 'name', 'slug', 'status', 'timezone', 'locale', 'created_at', 'updated_at')
  end

  def self.member(record)
    record.attributes.slice('id', 'team_id', 'user_id', 'role', 'status', 'created_at').merge(
      user: record.user.attributes.slice('id', 'email', 'username', 'first_name', 'last_name')
    )
  end

  def self.invitation(record)
    record.attributes.slice('id', 'team_id', 'normalized_email', 'role', 'expires_at', 'accepted_at', 'revoked_at',
                            'created_at')
  end

  def self.audit_event(record)
    record.attributes.slice('id', 'team_id', 'actor_type', 'actor_id', 'action', 'target_type', 'target_id',
                            'request_id', 'reason', 'metadata', 'occurred_at')
  end
end

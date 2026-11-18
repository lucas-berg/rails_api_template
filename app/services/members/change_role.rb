# frozen_string_literal: true

module Members
  class ChangeRole < Collaboration::Operation
    def call(member_id, role)
      within_team do
        member = active_member!(member_id)
        Pundit.authorize(actor, member, :update?)
        validate_role!(member, role)
        return member if member.role == role

        ensure_owner_retained!(member)
        update_role!(member, role)
        member
      end
    end

    private

    # Keep the role change, audit, and recipient notification in the same team transaction.
    # :reek:FeatureEnvy
    def update_role!(member, role)
      previous_role = member.role
      member.update!(role:)
      event = audit!('member.role_changed', member, previous_role:, role:)
      Notifications::Publish.call(user: member.user, team:, kind: 'member_role_changed',
                                  event_key: "audit:#{event.id}:member_role_changed")
    end

    def validate_role!(member, role)
      unless %w[admin member viewer].include?(role)
        raise Collaboration::Conflict.new('invalid_role_transition', 'Use ownership transfer to grant the owner role')
      end

      Pundit.authorize(actor, member, :grant_admin?) if role == 'admin'
    end
  end
end

# frozen_string_literal: true

module Members
  class ChangeRole < Collaboration::Operation
    def call(member_id, role)
      within_team do
        member = active_member!(member_id)
        authorize!(:update, member)
        validate_role!(role)
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

    def validate_role!(role)
      unless %w[admin member viewer].include?(role)
        raise Collaboration::Conflict.new('invalid_role_transition', 'Use ownership transfer to grant the owner role')
      end

      membership = team.active_members.find_by!(user_id: actor.id)
      raise Authorization::Forbidden, 'Only an owner can grant admin' if role == 'admin' && !membership.owner?
    end
  end
end

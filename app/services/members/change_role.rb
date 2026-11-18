# frozen_string_literal: true

module Members
  class ChangeRole < Collaboration::Operation
    def call(member_id, role)
      within_team do
        member = active_member!(member_id)
        authorize!(:update, member)
        validate_role!(role)
        previous_role = member.role
        ensure_owner_retained!(member) if previous_role != role
        member.update!(role:)
        audit!('member.role_changed', member, previous_role:, role:)
        member
      end
    end

    private

    def validate_role!(role)
      unless %w[admin member viewer].include?(role)
        raise Collaboration::Conflict.new('invalid_role_transition', 'Use ownership transfer to grant the owner role')
      end

      membership = team.active_members.find_by!(user_id: actor.id)
      raise Authorization::Forbidden, 'Only an owner can grant admin' if role == 'admin' && !membership.owner?
    end
  end
end

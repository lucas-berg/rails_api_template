# frozen_string_literal: true

module Members
  class Remove < Collaboration::Operation
    def call(member_id)
      within_team do
        member = active_member!(member_id)
        authorize!(:remove, member)
        ensure_owner_retained!(member)
        member.update!(status: 'removed')
        audit!('member.removed', member)
        member
      end
    end
  end
end

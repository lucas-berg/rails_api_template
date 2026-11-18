# frozen_string_literal: true

module Members
  class TransferOwnership < Collaboration::Operation
    def call(member_id)
      within_team do
        authorize!(:transfer_ownership, team)
        previous_owner = team.active_members.find_by!(user_id: actor.id)
        new_owner = active_member!(member_id)
        if new_owner == previous_owner
          raise Collaboration::Conflict.new('already_owner',
                                            'Choose another active member')
        end

        transfer!(previous_owner, new_owner)
        new_owner
      end
    end

    private

    def transfer!(previous_owner, new_owner)
      new_owner.update!(role: 'owner')
      previous_owner.update!(role: 'admin')
      audit!('team.ownership_transferred', team, previous_owner_id: previous_owner.id, new_owner_id: new_owner.id)
    end
  end
end

# frozen_string_literal: true

module Members
  class TransferOwnership < Collaboration::Operation
    def call(member_id)
      recipient = team.active_members.find(member_id).user
      Lifecycle::MembershipLock.with_user(recipient) do
        Lifecycle::OwnerGuard.accepting_memberships!(recipient)
        transfer_to(member_id)
      end
    end

    private

    def transfer_to(member_id)
      within_team do
        Pundit.authorize(actor, team, :transfer_ownership?)
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

    def transfer!(previous_owner, new_owner)
      new_owner.update!(role: 'owner')
      previous_owner.update!(role: 'admin')
      event = audit!('team.ownership_transferred', team,
                     previous_owner_id: previous_owner.id, new_owner_id: new_owner.id)
      notify_owner(previous_owner, event)
      notify_owner(new_owner, event)
    end

    def notify_owner(member, event)
      Notifications::Publish.call(user: member.user, team:, kind: 'ownership_transferred',
                                  event_key: "audit:#{event.id}:ownership_transferred")
    end
  end
end

# frozen_string_literal: true

module Invitations
  class Revoke < Collaboration::Operation
    def call(invitation_id)
      within_team do
        invitation = team.invitations.find(invitation_id)
        Pundit.authorize(actor, invitation, :destroy?)
        raise Collaboration::Conflict.new('invitation_accepted', 'Remove the member instead') if invitation.accepted_at

        unless invitation.revoked_at
          invitation.update!(revoked_at: Time.current)
          audit!('invitation.revoked', invitation)
        end
        invitation
      end
    end
  end
end

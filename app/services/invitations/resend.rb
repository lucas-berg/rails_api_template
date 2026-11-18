# frozen_string_literal: true

module Invitations
  class Resend < Operation
    def call(invitation_id)
      within_team do
        invitation = team.invitations.find(invitation_id)
        authorize!(:resend, invitation)
        if invitation.accepted_at || invitation.revoked_at
          raise Collaboration::Conflict.new('invitation_closed', 'This invitation is no longer open')
        end

        issue!(invitation)
        audit!('invitation.resent', invitation)
        invitation
      end
    end
  end
end

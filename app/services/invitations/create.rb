# frozen_string_literal: true

module Invitations
  class Create < Operation
    def call(email:, role: 'member')
      within_team do
        invitation = team.invitations.build(normalized_email: email, role:, invited_by: actor)
        authorize!(:create, invitation)
        check_existing!(email.to_s.strip.downcase)
        issue!(invitation)
        audit!('invitation.created', invitation, role:)
        invitation
      end
    end

    private

    def check_existing!(email)
      if team.active_members.joins(:user).exists?(users: { email: })
        raise Collaboration::Conflict.new('already_member', 'This user is already a team member')
      end

      previous = team.invitations.find_by(normalized_email: email, accepted_at: nil, revoked_at: nil)
      return unless previous

      raise Collaboration::Conflict.new('invitation_pending', 'Resend the existing invitation') if previous.pending?

      previous.update!(revoked_at: Time.current)
    end
  end
end

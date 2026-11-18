# frozen_string_literal: true

module Invitations
  class Accept
    def self.call(actor:, token:, request_id: nil)
      new(actor:, token:, request_id:).call
    end

    def initialize(actor:, token:, request_id: nil)
      @actor = actor
      @token = token.to_s
      @request_id = request_id
    end

    def call
      @invitation = Invitation.find_by!(token_digest: Digest::SHA256.hexdigest(@token))
      @team = @invitation.team
      @team.with_lock do
        @invitation.reload
        validate_acceptance!
        member = @team.members.find_or_initialize_by(user_id: @actor.id)
        return member if @invitation.accepted_at && member.persisted? && member.active?

        validate_pending!
        accept_member!(member)
      end
    end

    private

    def validate_pending!
      unless @invitation.pending?
        raise Collaboration::Conflict.new('invitation_closed', 'This invitation is no longer valid')
      end
      return if Authorization.allowed?(@invitation.invited_by, :create, @invitation, team: @team)

      raise Collaboration::Conflict.new('invitation_closed', 'The inviter can no longer grant this access')
    end

    # Acceptance coordinates membership, invitation, and audit in one transaction.
    # :reek:FeatureEnvy
    def accept_member!(member)
      member.assign_attributes(role: @invitation.role, status: 'active') unless member.persisted? && member.active?
      member.save!
      @invitation.update!(accepted_at: Time.current)
      AuditEvent.record!(actor: @actor, action: 'invitation.accepted', target: @invitation, team: @team,
                         request_id: @request_id, metadata: { member_id: member.id })
      publish_acceptance
      member
    end

    def publish_acceptance
      Notifications::Publish.call(user: @actor, team: @team, kind: 'invitation_accepted',
                                  event_key: "invitation:#{@invitation.id}:accepted")
    end

    def validate_acceptance!
      unless @actor.active_for_authentication? && @actor.confirmed? && @actor.email == @invitation.normalized_email
        raise Authorization::Forbidden, 'Sign in with the verified email address receiving this invitation'
      end
      raise Collaboration::Conflict.new('team_suspended', 'This team is suspended') unless @team.active?
      raise ActiveRecord::RecordNotFound unless @invitation.token_matches?(@token)
    end
  end
end

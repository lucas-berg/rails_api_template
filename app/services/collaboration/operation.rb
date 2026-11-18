# frozen_string_literal: true

module Collaboration
  class Operation
    def initialize(actor:, team:, request_id: nil)
      @actor = actor
      @team = team
      @request_id = request_id
    end

    private

    attr_reader :actor, :team, :request_id

    def within_team
      team.with_lock do
        raise Conflict.new('team_suspended', 'This team is suspended') unless team.active?

        yield
      end
    end

    def authorize!(action, target)
      Authorization.authorize!(actor, action, target, team:)
    end

    def audit!(action, target, metadata = {})
      AuditEvent.record!(actor:, action:, target:, team:, request_id:, metadata:)
    end

    def active_member!(id)
      team.active_members.find(id)
    end

    def ensure_owner_retained!(member)
      return unless member.owner? && team.active_members.owner.count <= 1

      raise Conflict.new('last_owner', 'Transfer ownership before removing the last owner')
    end
  end
end

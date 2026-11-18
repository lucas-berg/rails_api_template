# frozen_string_literal: true

module Authorization
  class Forbidden < StandardError; end

  def self.allowed?(actor, action, resource, team: nil)
    return false unless actor.is_a?(User)

    policy_for(actor, resource, team)&.allowed?(action) == true
  end

  # Explicit context is checked against the record by each tenant policy.
  # :reek:ControlParameter
  def self.policy_for(actor, resource, team)
    case resource
    when Team then TeamPolicy.new(actor, resource)
    when Notification then NotificationPolicy.new(actor, resource)
    when Member, Invitation, Document, DataExport then tenant_policy_for(actor, resource, team || resource.team)
    end
  end

  def self.tenant_policy_for(actor, resource, team)
    case resource
    when Member then MemberPolicy.new(actor, resource, team)
    when Invitation then InvitationPolicy.new(actor, resource, team)
    when Document then DocumentPolicy.new(actor, resource, team)
    when DataExport then DataExportPolicy.new(actor, resource, team)
    end
  end

  def self.authorize!(actor, action, resource, team: nil)
    raise Forbidden, 'You do not have permission to perform this action' unless allowed?(actor, action, resource, team:)
  end

  def self.team_scope(actor)
    return Team.none unless actor.is_a?(User) && actor.active_for_authentication? && actor.confirmed?

    actor.teams
  end
end

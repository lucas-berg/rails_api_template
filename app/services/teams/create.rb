# frozen_string_literal: true

module Teams
  class Create
    def self.call(actor:, attributes:, request_id: nil)
      team = Team.new(attributes.slice(:name, :locale, :timezone))
      Authorization.authorize!(actor, :create, team)
      Team.transaction do
        team.save!
        team.members.create!(user: actor, role: 'owner')
        AuditEvent.record!(actor:, action: 'team.created', target: team, team:, request_id:)
      end
      team
    end
  end
end

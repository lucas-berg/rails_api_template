# frozen_string_literal: true

module Teams
  class Create
    def self.call(actor:, attributes:, request_id: nil)
      actor.with_lock do
        team = Team.new(attributes.slice(:name, :locale, :timezone))
        Pundit.authorize(actor, team, :create?)
        team.save!
        team.members.create!(user: actor, role: 'owner')
        AuditEvent.record!(actor:, action: 'team.created', target: team, team:, request_id:)
        team
      end
    end
  end
end

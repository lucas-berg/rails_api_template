# frozen_string_literal: true

module Teams
  class Create
    def self.call(actor:, attributes:, request_id: nil)
      Lifecycle::MembershipLock.with_user(actor) do
        Lifecycle::OwnerGuard.accepting_memberships!(actor)
        persist(actor, attributes, request_id)
      end
    end

    def self.persist(actor, attributes, request_id)
      team = Team.new(attributes.slice(:name, :locale, :timezone))
      Pundit.authorize(actor, team, :create?)
      team.save!
      team.members.create!(user: actor, role: 'owner')
      AuditEvent.record!(actor:, action: 'team.created', target: team, team:, request_id:)
      team
    end

    private_class_method :persist
  end
end

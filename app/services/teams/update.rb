# frozen_string_literal: true

module Teams
  class Update < Collaboration::Operation
    def call(attributes)
      within_team do
        Pundit.authorize(actor, team, :update?)
        team.update!(attributes.slice(:name, :locale, :timezone))
        audit!('team.updated', team, attributes)
      end
      team
    end
  end
end

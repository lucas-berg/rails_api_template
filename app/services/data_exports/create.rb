# frozen_string_literal: true

module DataExports
  class Create < Collaboration::Operation
    def call
      team.with_lock do
        actor.reload
        export = DataExport.new(team:, requested_by: actor)
        raise Authorization::Forbidden unless DataExportPolicy.new(actor, export, team).allowed?(:create)

        export.save!
        audit!('export.requested', export)
        export
      end
    end
  end
end

# frozen_string_literal: true

module JobDeletionContext
  def self.for(deletion_id)
    deletion = DeletionRequest.find_by(id: deletion_id)
    return {} unless deletion

    team = Team.find_by(id: deletion.subject_id) if deletion.subject_type == 'Team'
    { user: deletion.requested_by, team: }
  end
end

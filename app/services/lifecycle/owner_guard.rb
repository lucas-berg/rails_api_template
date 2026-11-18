# frozen_string_literal: true

module Lifecycle
  module OwnerGuard
    def self.lock_teams(user)
      team_ids = Member.where(user: user, status: 'active').select(:team_id)
      Team.where(id: team_ids).order(:id).lock.load
      yield
    end

    def self.check!(user)
      team_ids = Member.where(user: user, status: 'active', role: 'owner').select(:team_id)
      owner_counts = Member.where(team_id: team_ids, role: 'owner', status: 'active').group(:team_id).count
      return unless owner_counts.values.any? { |count| count <= 1 }

      raise Collaboration::Conflict.new('last_owner', 'Transfer team ownership before deleting your account')
    end

    def self.accepting_memberships!(user)
      if user.deleted_at || DeletionRequest.exists?(subject: user, status: %w[pending processing failed])
        raise Collaboration::Conflict.new('account_deletion_pending',
                                          'Cancel account deletion before joining or creating a team')
      end
      raise Pundit::NotAuthorizedError unless user.active_for_authentication?
    end
  end
end

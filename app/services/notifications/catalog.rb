# frozen_string_literal: true

module Notifications
  module Catalog
    EVENTS = {
      'password_changed' => ['security', 'Your password changed', 'The password for your account was changed.'],
      'account_suspended' => ['security', 'Your account was suspended', 'Access to your account has been suspended.'],
      'account_restored' => ['security', 'Your account was restored', 'You can sign in to your account again.'],
      'invitation_accepted' => ['activity', 'You joined a team', 'Your team invitation was accepted.'],
      'member_role_changed' => ['activity', 'Your team role changed', 'Your permissions in this team have changed.'],
      'ownership_transferred' => ['activity', 'Team ownership changed', 'Ownership of this team has been transferred.'],
      'export.ready' => ['activity', 'Your export is ready', 'Your team export is ready to download.'],
      'deletion.team_requested' => ['activity', 'Team deletion requested', 'Deletion of this team has been scheduled.'],
      'deletion.team_canceled' => ['activity', 'Team deletion canceled',
                                   'The request to delete this team was canceled.'],
      'deletion.account_requested' => ['security', 'Account deletion requested',
                                       'Deletion of your account was scheduled.'],
      'deletion.account_canceled' => ['security', 'Account deletion canceled',
                                      'Your account deletion request was canceled.'],
      'deletion.team_completed' => ['security', 'Team deleted', 'The requested team deletion has completed.']
    }.freeze

    def self.category(kind)
      EVENTS.fetch(kind).first
    end

    def self.text(kind)
      _, title, body = EVENTS.fetch(kind)
      { 'title' => title, 'body' => body }
    end
  end
end

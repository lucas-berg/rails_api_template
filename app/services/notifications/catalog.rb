# frozen_string_literal: true

module Notifications
  module Catalog
    EVENTS = {
      'password_changed' => 'security',
      'account_suspended' => 'security',
      'account_restored' => 'security',
      'invitation_accepted' => 'activity',
      'member_role_changed' => 'activity',
      'ownership_transferred' => 'activity',
      'deletion.team_requested' => 'activity',
      'deletion.team_canceled' => 'activity',
      'deletion.account_requested' => 'security',
      'deletion.account_canceled' => 'security',
      'deletion.team_completed' => 'security'
    }.freeze
    LOCALES = %w[en zh-CN].freeze

    def self.category(kind)
      EVENTS.fetch(kind)
    end

    def self.text(kind, user: nil, team: nil)
      EVENTS.fetch(kind)
      locale = locale_for(user, team)
      %w[title body].index_with do |field|
        key = "notifications.#{kind}.#{field}"
        I18n.t(key, locale:, default: I18n.t(key, locale: :en, raise: true))
      end
    end

    def self.locale_for(user, team)
      [user&.preferences&.fetch('locale', nil), team&.locale, 'en'].find { |locale| LOCALES.include?(locale) }
    end
  end
end

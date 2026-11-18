# frozen_string_literal: true

module TeamMemberships
  extend ActiveSupport::Concern

  included do
    has_many :members, dependent: :restrict_with_error
    has_many :active_members, -> { active }, class_name: 'Member', dependent: :restrict_with_error, inverse_of: :user
    has_many :teams, through: :active_members

    validate :valid_preferences
  end

  # A caller can supply its authorized team to resolve the preference hierarchy.
  # :reek:ControlParameter
  def effective_preferences(team: nil)
    defaults = { 'locale' => team&.locale || 'en', 'timezone' => team&.timezone || 'UTC' }
    defaults.merge(preferences)
  end

  private

  def valid_preferences
    return errors.add(:preferences, 'must be an object') unless preferences.is_a?(Hash)

    errors.add(:preferences, 'contains unknown fields') if (preferences.keys - %w[locale timezone]).any?
    validate_preferred_locale
    validate_preferred_timezone
  end

  def validate_preferred_locale
    return unless preferences.key?('locale') && Team::LOCALES.exclude?(preferences['locale'])

    errors.add(:preferences, 'locale is not supported')
  end

  def validate_preferred_timezone
    return unless preferences.key?('timezone')

    timezone = preferences['timezone']
    errors.add(:preferences, 'timezone is not valid') unless timezone.is_a?(String) && ActiveSupport::TimeZone[timezone]
  end
end

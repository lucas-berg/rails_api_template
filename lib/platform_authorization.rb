# frozen_string_literal: true

class PlatformAuthorization < ActiveAdmin::AuthorizationAdapter
  READABLE = %w[User AdminUser Team Member Invitation AuditEvent AuthSession MailDelivery Notification
                NotificationDelivery Document DataExport].freeze
  ACTIONS = { 'AdminUser' => %i[create update], 'User' => %i[suspend restore],
              'Team' => %i[suspend restore], 'MailDelivery' => [:retry_delivery],
              'NotificationDelivery' => [:retry_delivery], 'Document' => [:retry_purge] }.freeze

  def authorized?(action, subject = nil)
    return false unless user.is_a?(AdminUser)
    return page_authorized?(action, subject) if subject.is_a?(ActiveAdmin::Page)

    name = model_name(subject)
    return true if action == :read && READABLE.include?(name)

    user.super_admin? && ACTIONS.fetch(name, []).include?(action)
  end

  # ActiveAdmin supplies either a model class or a relation to this adapter hook.
  # :reek:FeatureEnvy
  def scope_collection(collection, action = :read)
    model = collection.is_a?(Class) ? collection : collection.klass
    authorized?(action, model) ? collection : collection.none
  end

  private

  def model_name(subject)
    subject.is_a?(Class) ? subject.name : subject.class.name
  end

  # The adapter must explicitly distinguish read access from all other actions.
  # :reek:ControlParameter
  def page_authorized?(action, subject)
    action == :read && subject.name == 'Dashboard'
  end
end

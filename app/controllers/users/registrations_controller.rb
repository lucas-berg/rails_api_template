# frozen_string_literal: true

module Users
  class RegistrationsController < Devise::RegistrationsController
    protected

    # Devise owns the update hook; refresh and authorize its supplied account under the row lock.
    # :reek:FeatureEnvy
    def update_resource(resource, attributes)
      resource.with_lock do
        unless resource.active_for_authentication?
          resource.errors.add(:base, 'This account is no longer active.')
          return false
        end

        super
      end
    end

    def after_sign_up_path_for(_resource)
      account_path
    end

    def after_inactive_sign_up_path_for(_resource)
      new_user_session_path
    end
  end
end

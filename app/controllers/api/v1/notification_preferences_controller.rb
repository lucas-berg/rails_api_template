# frozen_string_literal: true

module API
  module V1
    class NotificationPreferencesController < SaasController
      def show
        preference = NotificationPreference.for(current_user)
        authorize preference, :show?
        render_data(preference.presentation)
      end

      def update
        authorize NotificationPreference.new(user: current_user), :update?
        attributes = attributes_for(:notification_preferences, %i[activity_in_app activity_email])
        unless attributes.values.all? { |value| NotificationPreference::BOOLEAN_VALUES.include?(value) }
          raise ActionController::BadRequest, 'Notification preferences must be boolean values'
        end

        preference = NotificationPreference.create_or_find_by!(user: current_user)
        preference.update!(attributes)
        render_data(preference.presentation)
      end
    end
  end
end

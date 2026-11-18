# frozen_string_literal: true

module API
  module V1
    class UsersController < API::V1::APIController
      def show
        render 'api/v1/users/show'
      end

      def update
        attributes = update_user_params
        if attributes.key?(:email) && attributes[:email] != current_user.email
          raise ActiveRecord::RecordInvalid, current_user unless current_user.update_with_password(attributes)
        else
          current_user.update!(attributes.except(:current_password))
        end
        show
      end

      private

      def update_user_params
        supplied_user = params.require(:user)
        preferences = supplied_user[:preferences] if supplied_user.is_a?(ActionController::Parameters)
        validate_preference_keys!(preferences)
        params.expect(user: [:username, :first_name, :last_name, :email, :current_password,
                             { preferences: %i[locale timezone] }])
      end

      def validate_preference_keys!(preferences)
        if preferences && (!preferences.is_a?(ActionController::Parameters) || (preferences.keys - %w[locale
                                                                                                      timezone]).any?)
          current_user.errors.add(:preferences, 'contains invalid fields')
          raise ActiveRecord::RecordInvalid, current_user
        end
      end
    end
  end
end

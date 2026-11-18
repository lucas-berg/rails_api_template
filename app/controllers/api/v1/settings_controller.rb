# frozen_string_literal: true

module API
  module V1
    class SettingsController < API::V1::APIController
      skip_before_action :authenticate_user!

      def must_update
        supplied_version = params[:device_version]
        if supplied_version.present? && !(supplied_version.is_a?(String) && Gem::Version.correct?(supplied_version))
          render json: { errors: [{ message: 'Invalid device_version' }] }, status: :bad_request
          return
        end

        current_version = Gem::Version.new(supplied_version.presence || '0')
        min_version = Gem::Version.new(version || '0.0.0')
        must_update = min_version > current_version
        render json: { must_update: }
      end

      private

      def version
        Setting.find_by(key: 'min_version')&.value
      end
    end
  end
end

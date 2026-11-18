# frozen_string_literal: true

module API
  module V1
    class TeamSettingsController < TeamContextController
      def show
        authorize!(:read, @team)
        render_settings
      end

      def update
        Teams::Update.new(**operation_options).call(attributes_for(:settings, %i[name timezone locale]))
        render_settings
      end

      private

      def render_settings
        render_data(@team.attributes.slice('name', 'timezone', 'locale'))
      end
    end
  end
end

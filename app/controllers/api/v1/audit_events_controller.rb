# frozen_string_literal: true

module API
  module V1
    class AuditEventsController < TeamContextController
      def index
        authorize!(:audit, @team)
        render_collection(filtered_events) { |event| SaasPresenter.audit_event(event) }
      end

      private

      def filtered_events
        events = @team.audit_events.where(params.permit(:actor_id))
        action_name = params[:action_name]
        events = events.where(action: action_name) if action_name.present?
        events
      end
    end
  end
end

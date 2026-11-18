# frozen_string_literal: true

module RequestContext
  extend ActiveSupport::Concern

  included do
    prepend_around_action :with_request_context
  end

  private

  def with_request_context
    Current.set(user: nil, team: nil, request_id: request.request_id, job_id: nil) do
      yield
    ensure
      request.env['saas.context'] = { user_id: Current.user&.id, team_id: Current.team&.id }
    end
  ensure
    Current.reset
  end
end

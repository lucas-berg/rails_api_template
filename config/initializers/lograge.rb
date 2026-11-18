# frozen_string_literal: true

Rails.application.configure do
  config.lograge.enabled = Rails.env.production?
  config.lograge.base_controller_class = ['ActionController::API', 'ActionController::Base']
  config.lograge.custom_payload do |controller|
    request = controller.request
    {
      current_user_id: controller.current_user&.id,
      host: request.host,
      path: request.path,
      user_agent: request.user_agent,
      remote_ip: request.remote_ip,
      request_id: request.request_id,
      team_id: Current.team&.id
    }
  end
end

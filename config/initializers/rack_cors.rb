# frozen_string_literal: true

module App
  class Application < Rails::Application
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins(*ENV.fetch('CORS_ALLOWED_ORIGINS', Rails.env.production? ? '' : 'http://localhost:3000,http://127.0.0.1:3000')
                    .split(',').map(&:strip).reject(&:empty?))
        resource '*',
                 headers: :any,
                 methods: %i[get post options put patch delete],
                 expose: %w[Authorization]
      end
    end
  end
end

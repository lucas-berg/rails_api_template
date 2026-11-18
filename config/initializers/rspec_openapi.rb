# frozen_string_literal: true

return unless Rails.env.test?

require 'rspec/openapi'

RSpec::OpenAPI.openapi_version = '3.0.3'
RSpec::OpenAPI.title = 'rails_api_template'
RSpec::OpenAPI.path = ENV.fetch('OPENAPI_OUTPUT', 'doc/openapi.yaml')
RSpec::OpenAPI.enable_example = false
RSpec::OpenAPI.security_schemes = {
  'BearerAuth' => { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' }
}
RSpec::OpenAPI.response_headers = %w[Authorization]

if ENV['OPENAPI']
  RSpec.configure do |config|
    config.prepend_after(:example, type: :request) do
      # Warden rewrites PATH_INFO when invoking Devise's failure app. Document the caller's route.
      attempted_path = request&.get_header('warden.options')&.fetch(:attempted_path, nil)
      request.path_info = attempted_path.split('?', 2).first if attempted_path
    end
  end
end

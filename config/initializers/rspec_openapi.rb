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
RSpec::OpenAPI.response_headers = %w[Authorization Location Retry-After Content-Disposition Cache-Control
                                     X-Content-Type-Options Content-Security-Policy]

RSpec::OpenAPI.post_process_hook = lambda do |_path, _records, spec|
  # A downloaded JSON attachment is a binary response, not a string with object properties.
  spec.fetch(:paths).each_value do |operations|
    operations.each_value do |operation|
      operation.fetch(:responses, {}).each_value do |response|
        response.fetch(:content, {}).each_value do |content|
          content[:schema] = { type: 'string', format: 'binary' } if content.dig(:schema, :format) == 'binary'
        end
      end
    end
  end

  # The generator omits all DELETE bodies; these two API actions require password confirmation.
  ['/users', '/api/v1/deletion_requests/{id}'].each do |path|
    operation = spec.dig(:paths, path.to_sym, :delete)
    next unless operation

    operation[:requestBody] = {
      required: true,
      content: { 'application/json': {
        schema: { type: 'object', required: ['current_password'],
                  properties: { current_password: { type: 'string', format: 'password', writeOnly: true } } }
      } }
    }
  end
end

if ENV['OPENAPI']
  RSpec.configure do |config|
    config.prepend_after(:example, type: :request) do
      # Warden rewrites PATH_INFO when invoking Devise's failure app. Document the caller's route.
      attempted_path = request&.get_header('warden.options')&.fetch(:attempted_path, nil)
      request.path_info = attempted_path.split('?', 2).first if attempted_path
    end
  end
end

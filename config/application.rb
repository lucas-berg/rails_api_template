# frozen_string_literal: true

require_relative 'boot'

require 'rails/all'
require 'uri'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module App
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1
    # File features are not exposed by this template.
    config.active_storage.draw_routes = false

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.x.public_url = ENV.fetch('APP_PUBLIC_URL') {
      protocol = Rails.env.production? ? 'https' : 'http'
      "#{protocol}://#{ENV.fetch('SERVER_HOST', 'localhost')}:#{ENV.fetch('PORT', 3000)}"
    }.delete_suffix('/')
    public_uri = URI.parse(config.x.public_url)
    config.action_mailer.smtp_settings = {
      address: 'smtp.sendgrid.net',
      authentication: :plain,
      domain: public_uri.host,
      enable_starttls_auto: true,
      password: ENV.fetch('SENDGRID_API_KEY', nil),
      port: 587,
      user_name: 'apikey',
      open_timeout: 10,
      read_timeout: 30
    }
    config.action_mailer.default_url_options = { host: public_uri.host, port: public_uri.port,
                                                 protocol: public_uri.scheme }
    config.action_mailer.default_options = {
      from: ENV.fetch('DEFAULT_EMAIL_SENDER', 'no-reply@example.com')
    }

    config.action_mailer.deliver_later_queue_name = 'mailers'

    config.generators do |g|
      g.test_framework :rspec, view_specs: false, helper_specs: false, routing_specs: false, request_specs: false
      g.fixture_replacement :factory_bot, dir: 'spec/factories'
    end

    # Log N+1s using Rails strict_loading feature
    ENV['DISABLE_RAILS_STRICT_LOADING'] ||= 'true' if defined?(Rails::Console)
    config.active_record.strict_loading_by_default = ENV['DISABLE_RAILS_STRICT_LOADING'] != 'true'
    config.active_record.action_on_strict_loading_violation = :log
  end
end

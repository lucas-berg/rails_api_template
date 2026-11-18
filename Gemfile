# frozen_string_literal: true

source 'https://rubygems.org'

ruby '3.3.13'

gem 'rails', '~> 8.1.4', '>= 8.1.4.1'

# DB and Server
gem 'pg', '~> 1.7'
gem 'pghero', '~> 4.1'
gem 'puma', '~> 8.1'

# Frontend
gem 'activeadmin', '~> 3.5'
gem 'cssbundling-rails', '~> 1.4'
gem 'jsbundling-rails', '~> 1.3'
gem 'sprockets-rails', '~> 3.5', '>= 3.5.2'
gem 'stimulus-rails', '~> 1.3'
gem 'tailwindcss-rails', '~> 4.7'
gem 'turbo-rails', '~> 2.0'

# Users
gem 'devise', '~> 5.0'
gem 'devise-jwt', '~> 0.13.0'

# API
gem 'jbuilder', '~> 2.15'
gem 'oj', '~> 3.17'
gem 'rack-attack'
gem 'rack-cors', '~> 3.0'
gem 'rails_param', '~> 1.3.1'
gem 'redis', '~> 5.0'

# Tools
gem 'dotenv-rails', '~> 3.2.0'
gem 'enumerize', '~> 3.0'
gem 'groupdate', '~> 6.8'
gem 'pagy', '~> 43.8'
gem 'ransack', '~> 6.1'
gem 'ruby_llm', '~> 2.2'

# Monitoring
gem 'newrelic_rpm', '~> 10.9'
gem 'sentry-ruby', '~> 7.2'

# Storage
gem 'active_storage_base64', '~> 3.0.1'

# Doc
gem 'rswag-api', '~> 2.17.0'
gem 'rswag-ui', '~> 2.17.0'

gem 'bootsnap', '~> 1.26'
gem 'flipper', '~> 1.4'
gem 'flipper-active_record', '~> 1.4'
gem 'flipper-ui', '~> 1.4'
gem 'lograge', '~> 0.16'

# Queue
gem 'good_job', '~> 4.24'

gem 'yaaf', '~> 3.1'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'
# Use Active Storage variant
# gem 'image_processing', '~> 1.2'

group :development, :test do
  gem 'annotaterb', '~> 4.26'
  gem 'chaotic_order', '~> 0.1.0'
  gem 'factory_bot_rails', '~> 6.5'
  gem 'faker', '~> 3.8'
  gem 'pry-byebug', '~> 3.12', platform: :mri
  gem 'pry-rails', '~> 0.3.11'
  gem 'rspec-rails', '~> 8.1'
end

group :development do
  gem 'better_errors', '~> 2.10'
  gem 'binding_of_caller', '~> 2.0'
  gem 'brakeman', '~> 8.1'
  gem 'i18n-tasks', '~> 1.2'
  gem 'letter_opener', '~> 1.10'
  gem 'listen', '~> 3.10'
  gem 'rails_best_practices', '~> 1.23'
  gem 'reek', '~> 6.6'
  gem 'rubocop', '~> 1.92', require: false
  gem 'rubocop-capybara', '~> 3.1'
  gem 'rubocop-factory_bot', '~> 2.28', require: false
  gem 'rubocop-performance', '~> 1.27', require: false
  gem 'rubocop-rails', '~> 2.38', require: false
  gem 'rubocop-rake', '~> 0.7.1', require: false
  gem 'rubocop-rspec', '~> 3.10', require: false
  gem 'rubocop-rspec_rails', '~> 2.33', require: false
end

group :test do
  gem 'capybara', '~> 3.40'
  gem 'faraday-retry', '~> 2.4'
  gem 'knapsack', '~> 4.0'
  gem 'octokit', '~> 10.0'
  gem 'parallel_tests', '~> 5.9'
  gem 'pg_query', '~> 6.2'
  gem 'prosopite', '~> 2.5'
  gem 'rspec-openapi', '~> 0.36'
  # gem 'rspec-retry', github: 'tianlu1677/rspec-retry', branch: 'add-intermittent-callback'
  gem 'selenium-webdriver', '~> 4.53'
  gem 'shoulda-matchers', '~> 8.0'
  gem 'simplecov', '~> 1.3', require: false
  gem 'webmock', '~> 3.34'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[windows jruby]

# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: -> { Rails.configuration.action_mailer.default_options.fetch(:from) }
  layout 'mailer'
end

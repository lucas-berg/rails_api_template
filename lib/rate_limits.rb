# frozen_string_literal: true

module RateLimits
  class Exceeded < StandardError
    attr_reader :retry_after

    def initialize(retry_after)
      @retry_after = retry_after
      super('Too many requests. Please try again later.')
    end
  end

  def self.store
    ActiveSupport::Cache::RedisCacheStore.new(
      url: ENV.fetch('RATE_LIMIT_REDIS_URL', 'redis://localhost:6379/2'),
      namespace: "saas:rate_limits:#{Rails.env}",
      error_handler: ->(exception:, **) { raise exception }
    )
  end

  def self.email(request)
    params = request.media_type == 'application/json' ? json_body(request) : request.params
    value = nested_email(params)
    Digest::SHA256.hexdigest(value.strip.downcase) if value.is_a?(String) && value.present?
  rescue JSON::ParserError, Rack::QueryParser::ParameterTypeError
    nil
  end

  def self.nested_email(params)
    params.dig('user', 'email') if params.is_a?(Hash) && params['user'].is_a?(Hash)
  end

  def self.json_body(request)
    request.env['saas.rate_limit_body'] ||= begin
      body = request.body
      content = body.read
      body.rewind
      JSON.parse(content.presence || '{}')
    end
  end

  # Called only after team membership and invitation-management authorization.
  def self.check_invitation!(team_id)
    return unless Rack::Attack.enabled

    period = 1.hour.to_i
    current_time = Time.current.to_i
    key = "invitations:#{team_id}:#{current_time / period}"
    count = increment(key, period)
    limit = ENV.fetch('INVITATIONS_PER_HOUR', '30').to_i
    raise Exceeded, period - (current_time % period) if count > limit
  end

  def self.increment(key, period)
    Rack::Attack.cache.store.increment(key, 1, expires_in: period)
  end
end

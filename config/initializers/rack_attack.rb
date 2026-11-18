# frozen_string_literal: true

require Rails.root.join('lib/rate_limits')

Rack::Attack.enabled = !Rails.env.test?
Rack::Attack.cache.store = RateLimits.store

Rack::Attack.throttle('login/ip', limit: ENV.fetch('LOGINS_PER_MINUTE', '10').to_i, period: 1.minute) do |request|
  request.ip if request.post? && request.path.match?(%r{\A/(users|admin_users)/sign_in(?:\.json)?\z})
end

%w[confirmation password].each do |action|
  Rack::Attack.throttle("#{action}/email", limit: ENV.fetch('RECOVERY_PER_PERIOD', '3').to_i,
                                           period: 15.minutes) do |request|
    RateLimits.email(request) if request.post? && request.path.match?(%r{\A/users/#{action}(?:\.json)?\z})
  end
end

Rack::Attack.throttled_responder = lambda do |request|
  period = request.env.fetch('rack.attack.match_data').fetch(:period).to_i
  retry_after = period - (Time.current.to_i % period)
  body = { errors: [{ code: 'rate_limited', message: 'Too many requests. Please try again later.' }],
           request_id: request.env['action_dispatch.request_id'] }
  [429, { 'content-type' => 'application/json', 'retry-after' => retry_after.to_s }, [body.to_json]]
end

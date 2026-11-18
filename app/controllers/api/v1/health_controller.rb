# frozen_string_literal: true

module API
  module V1
    class HealthController < API::V1::APIController
      skip_before_action :authenticate_user!

      def status
        render json: { online: true }
      end

      def ready
        ActiveRecord::Base.connection.execute('SELECT 1')
        RateLimits.store.redis.with(&:ping)
        render json: { ready: true }
      rescue ActiveRecord::ActiveRecordError, Redis::BaseError, ConnectionPool::TimeoutError
        render json: { ready: false }, status: :service_unavailable
      end
    end
  end
end

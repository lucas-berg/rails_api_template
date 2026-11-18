# frozen_string_literal: true

module API
  module V1
    class SaasController < APIController
      skip_before_action :authenticate_user!
      before_action :authenticate_api_user!

      rescue_from Authorization::Forbidden, with: :render_forbidden
      rescue_from Collaboration::Conflict, with: :render_conflict
      rescue_from ActiveRecord::RecordNotUnique, with: :render_duplicate
      rescue_from ActionController::BadRequest, with: :render_bad_request
      rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
      rescue_from RateLimits::Exceeded, with: :render_rate_limited

      private

      def authenticate_api_user!
        return if current_user&.active_for_authentication?

        api_error('unauthenticated', 'Sign in to continue', :unauthorized)
      end

      def authorize!(action, resource)
        Authorization.authorize!(current_user, action, resource, team: Current.team)
      end

      def render_data(data, status: :ok, meta: {})
        render 'api/v1/saas/show', locals: { data:, meta: }, status:
      end

      def render_collection(relation, &)
        page, per_page = pagination
        total = relation.count
        records = relation.order(id: :asc).limit(per_page).offset((page - 1) * per_page)
        render_data(records.map(&), meta: { page:, per_page:, total: })
      end

      def pagination
        [[params.fetch(:page, 1).to_i, 1].max, params.fetch(:per_page, 20).to_i.clamp(1, 100)]
      end

      def api_error(code, message, status, field: nil)
        render json: { errors: [{ code:, message:, field: }], request_id: request.request_id }, status:
      end

      def render_not_found(_exception)
        api_error('not_found', 'The resource was not found', :not_found)
      end

      def render_record_invalid(exception)
        errors = exception.record.errors.map do |error|
          { code: 'validation_failed', message: error.full_message, field: error.attribute }
        end
        render json: { errors:, request_id: request.request_id }, status: :unprocessable_content
      end

      # Error translation belongs at the HTTP boundary.
      # :reek:FeatureEnvy
      def render_parameter_missing(exception)
        api_error('missing_parameter', exception.message, :bad_request, field: exception.param)
      end

      def render_forbidden(exception)
        api_error('forbidden', exception.message, :forbidden)
      end

      # :reek:FeatureEnvy
      def render_conflict(exception)
        api_error(exception.code, exception.message, :conflict)
      end

      def render_duplicate(_exception)
        api_error('duplicate', 'The resource already exists', :conflict)
      end

      def render_bad_request(exception)
        api_error('invalid_parameter', exception.message, :bad_request)
      end

      def render_rate_limited(exception)
        response.set_header('Retry-After', exception.retry_after.to_s)
        api_error('rate_limited', 'Too many requests. Please try again later', :too_many_requests)
      end

      def attributes_for(key, allowed)
        supplied = params.require(key)
        unless supplied.is_a?(ActionController::Parameters)
          raise ActionController::BadRequest, "#{key} must be an object"
        end

        unexpected = supplied.keys.map(&:to_sym) - allowed
        raise ActionController::BadRequest, "Unknown fields: #{unexpected.join(', ')}" unless unexpected.empty?

        supplied.permit(*allowed).to_h.symbolize_keys
      end
    end
  end
end

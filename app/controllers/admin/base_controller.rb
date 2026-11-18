# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    include Pundit::Authorization

    layout 'admin'
    before_action :authenticate_admin_user!
    before_action :require_html
    after_action :verify_authorized
    after_action :verify_policy_scoped, if: -> { action_name == 'index' }

    rescue_from Pundit::NotAuthorizedError, with: :access_denied
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from ActionController::ParameterMissing, ArgumentError, with: :bad_request
    rescue_from Ransack::InvalidSearchError, with: :bad_request

    private

    def pundit_user
      current_admin_user
    end

    def require_html
      head :not_acceptable unless request.format.html?
    end

    def paginate(scope)
      @page = params.fetch(:page, 1).to_i.clamp(1, 1_000_000)
      @per_page = params.fetch(:per_page, 20).to_i.clamp(1, 100)
      @total = scope.count
      scope.order(id: :desc).limit(@per_page).offset((@page - 1) * @per_page)
    end

    def not_found
      render plain: 'This record was not found.', status: :not_found
    end

    def bad_request(exception)
      render plain: exception.message, status: :bad_request
    end
  end
end

# frozen_string_literal: true

module Admin
  class AuthSessionsController < BaseController
    def index
      authorize([:admin, AuthSession], :index?)
      @filters = params.permit(q: {}).to_h
      @search = policy_scope([:admin, AuthSession]).ransack!(params[:q])
      @auth_sessions = paginate(@search.result)
    end

    def show
      @auth_session = policy_scope([:admin, AuthSession]).find(params.expect(:id))
      authorize([:admin, @auth_session], :show?)
    end
  end
end

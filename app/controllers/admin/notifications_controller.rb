# frozen_string_literal: true

module Admin
  class NotificationsController < BaseController
    def index
      authorize([:admin, Notification], :index?)
      @filters = params.permit(q: {}).to_h
      @search = policy_scope([:admin, Notification]).ransack!(params[:q])
      @notifications = paginate(@search.result)
    end

    def show
      @notification = policy_scope([:admin, Notification]).find(params.expect(:id))
      authorize([:admin, @notification], :show?)
    end
  end
end

# frozen_string_literal: true

module Admin
  class InvitationsController < BaseController
    def index
      authorize([:admin, Invitation], :index?)
      @filters = params.permit(q: {}).to_h
      @search = policy_scope([:admin, Invitation]).ransack!(params[:q])
      @invitations = paginate(@search.result)
    end

    def show
      @invitation = policy_scope([:admin, Invitation]).find(params.expect(:id))
      authorize([:admin, @invitation], :show?)
    end
  end
end

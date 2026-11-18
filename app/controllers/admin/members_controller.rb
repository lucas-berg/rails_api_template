# frozen_string_literal: true

module Admin
  class MembersController < BaseController
    def index
      authorize([:admin, Member], :index?)
      @filters = params.permit(q: {}).to_h
      @search = policy_scope([:admin, Member]).ransack!(params[:q])
      @members = paginate(@search.result)
    end

    def show
      @member = policy_scope([:admin, Member]).find(params.expect(:id))
      authorize([:admin, @member], :show?)
    end
  end
end

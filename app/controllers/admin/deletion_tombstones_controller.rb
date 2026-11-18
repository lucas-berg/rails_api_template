# frozen_string_literal: true

module Admin
  class DeletionTombstonesController < BaseController
    def index
      authorize([:admin, DeletionTombstone], :index?)
      @filters = params.permit(q: {}).to_h
      @search = policy_scope([:admin, DeletionTombstone]).ransack!(params[:q])
      @deletion_tombstones = paginate(@search.result)
    end

    def show
      @deletion_tombstone = policy_scope([:admin, DeletionTombstone]).find(params.expect(:id))
      authorize([:admin, @deletion_tombstone], :show?)
    end
  end
end

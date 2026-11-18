# frozen_string_literal: true

module Admin
  class DeletionRequestsController < BaseController
    before_action :load_record, only: %i[show retry_cleanup]

    def index
      authorize([:admin, DeletionRequest], :index?)
      @filters = params.permit(q: {}).to_h
      @search = policy_scope([:admin, DeletionRequest]).ransack!(params[:q])
      @deletion_requests = paginate(@search.result)
    end

    def show
      authorize([:admin, @deletion_request], :show?)
    end

    def retry_cleanup
      authorize([:admin, @deletion_request], :retry_cleanup?)
      Deletions::Retry.call(actor: current_admin_user, deletion: @deletion_request,
                            reason: params.require(:reason), request_id: request.request_id)
      redirect_to admin_deletion_request_path(@deletion_request), notice: I18n.t('admin.messages.retry_scheduled')
    end

    private

    def load_record
      @deletion_request = policy_scope([:admin, DeletionRequest]).find(params.expect(:id))
    end
  end
end

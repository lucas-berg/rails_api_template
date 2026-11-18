# frozen_string_literal: true

module Admin
  class MailDeliveriesController < BaseController
    before_action :load_record, only: %i[show retry_delivery]

    def index
      authorize([:admin, MailDelivery], :index?)
      @filters = params.permit(q: {}).to_h
      @search = policy_scope([:admin, MailDelivery]).ransack!(params[:q])
      @mail_deliveries = paginate(@search.result)
    end

    def show
      authorize([:admin, @mail_delivery], :show?)
    end

    def retry_delivery
      authorize([:admin, @mail_delivery], :retry_delivery?)
      Platform::RetryMail.call(actor: current_admin_user, delivery: @mail_delivery,
                               reason: params.require(:reason), request_id: request.request_id)
      redirect_to admin_mail_delivery_path(@mail_delivery), notice: I18n.t('admin.messages.retry_scheduled')
    end

    private

    def load_record
      @mail_delivery = policy_scope([:admin, MailDelivery]).find(params.expect(:id))
    end
  end
end

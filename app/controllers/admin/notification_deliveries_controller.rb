# frozen_string_literal: true

module Admin
  class NotificationDeliveriesController < BaseController
    before_action :load_record, only: %i[show retry_delivery]

    def index
      authorize([:admin, NotificationDelivery], :index?)
      @filters = params.permit(q: {}).to_h
      @search = policy_scope([:admin, NotificationDelivery]).ransack!(params[:q])
      @notification_deliveries = paginate(@search.result)
    end

    def show
      authorize([:admin, @notification_delivery], :show?)
    end

    def retry_delivery
      authorize([:admin, @notification_delivery], :retry_delivery?)
      Platform::RetryNotification.new(actor: current_admin_user, record: @notification_delivery,
                                      request_id: request.request_id).call(reason: params.require(:reason))
      redirect_to admin_notification_delivery_path(@notification_delivery),
                  notice: I18n.t('admin.messages.retry_scheduled')
    end

    private

    def load_record
      @notification_delivery = policy_scope([:admin, NotificationDelivery]).find(params.expect(:id))
    end
  end
end

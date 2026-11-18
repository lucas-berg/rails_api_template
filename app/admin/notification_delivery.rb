# frozen_string_literal: true

ActiveAdmin.register NotificationDelivery do
  actions :index, :show
  config.filters = false

  member_action :retry_delivery, method: :post do
    authorize! :retry_delivery, resource
    Platform::RetryDispatch.new(actor: current_admin_user, record: resource, request_id: request.request_id)
                           .call(reason: params.require(:reason))
    redirect_to resource_path, notice: I18n.t('saas.admin.mail_retried')
  end

  index do
    id_column
    column :notification_id
    column :channel
    column :status
    column :attempts
    column :next_attempt_at
    actions
  end

  show do
    attributes_table do
      row :notification_id
      row :channel
      row :status
      row :attempts
      row :next_attempt_at
      row :last_error
      row :sent_at
    end
    if current_admin_user.super_admin? && resource.status == 'failed'
      panel 'Retry notification' do
        form action: "/admin/notification_deliveries/#{resource.id}/retry_delivery", method: :post do
          input type: :hidden, name: :authenticity_token, value: form_authenticity_token
          input type: :text, name: :reason, placeholder: 'Reason', required: true
          input type: :submit, value: 'Retry'
        end
      end
    end
  end
end

# frozen_string_literal: true

ActiveAdmin.register MailDelivery do
  actions :index, :show
  filter :status, as: :select, collection: %w[pending sending sent failed skipped]
  filter :kind
  filter :team_id
  filter :user_id

  member_action :retry_delivery, method: :post do
    authorize! :retry_delivery, resource
    Platform::RetryMail.call(actor: current_admin_user, delivery: resource,
                             reason: params.require(:reason), request_id: request.request_id)
    redirect_to resource_path, notice: I18n.t('saas.admin.mail_retried')
  end

  index do
    id_column
    column :kind
    column :status
    column :attempts
    column :next_attempt_at
    column :last_error
    actions
  end

  show do
    attributes_table do
      row :kind
      row :user_id
      row :team_id
      row :status
      row :attempts
      row :next_attempt_at
      row :sent_at
      row :last_error
    end
    if current_admin_user.super_admin? && resource.status == 'failed'
      panel 'Retry delivery' do
        form action: "/admin/mail_deliveries/#{resource.id}/retry_delivery", method: :post do
          input type: :hidden, name: :authenticity_token, value: form_authenticity_token
          input type: :text, name: :reason, placeholder: 'Reason', required: true
          input type: :submit, value: 'Retry'
        end
      end
    end
  end
end

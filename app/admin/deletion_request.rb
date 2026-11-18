# frozen_string_literal: true

ActiveAdmin.register DeletionRequest do
  actions :index, :show
  filter :subject_type
  filter :subject_id
  filter :status, as: :select, collection: %w[pending processing failed completed canceled]

  member_action :retry_cleanup, method: :post do
    authorize! :retry_cleanup, resource
    Deletions::Retry.call(actor: current_admin_user, deletion: resource,
                          reason: params.require(:reason), request_id: request.request_id)
    redirect_to resource_path
  end

  index do
    id_column
    column :subject_type
    column :subject_id
    column :status
    column :stage
    column :scheduled_at
    column :failure_code
    actions
  end
  show do
    attributes_table do
      row :subject_type
      row :subject_id
      row :requested_by_id
      row :status
      row :stage
      row :scheduled_at
      row :completed_at
      row :attempts
      row :failure_code
      row :notice_attempts
      row :notice_failure_code
    end
    if current_admin_user.super_admin? && resource.status == 'failed'
      panel 'Retry cleanup' do
        form action: "/admin/deletion_requests/#{resource.id}/retry_cleanup", method: :post do
          input type: :hidden, name: :authenticity_token, value: form_authenticity_token
          input type: :text, name: :reason, placeholder: 'Reason', required: true
          input type: :submit, value: 'Retry'
        end
      end
    end
  end
end

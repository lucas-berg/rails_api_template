# frozen_string_literal: true

ActiveAdmin.register Document do
  actions :index, :show
  filter :team_id
  filter :uploader_id
  filter :status, as: :select, collection: Document::STATUSES

  member_action :retry_purge, method: :post do
    authorize! :retry_purge, resource
    Platform::RetryDispatch.new(actor: current_admin_user, record: resource, request_id: request.request_id)
                           .call(reason: params.require(:reason))
    redirect_to resource_path
  end

  index do
    id_column
    column :team_id
    column :uploader_id
    column :original_filename
    column :status
    column :byte_size
    actions
  end

  show do
    attributes_table do
      row :team_id
      row :uploader_id
      row :original_filename
      row :status
      row :byte_size
      row :verified_content_type
      row :failure_code
      row :last_error
      row :purge_attempts
      row :purged_at
    end
    if current_admin_user.super_admin? && resource.status == 'purge_failed'
      panel 'Retry file cleanup' do
        form action: "/admin/documents/#{resource.id}/retry_purge", method: :post do
          input type: :hidden, name: :authenticity_token, value: form_authenticity_token
          input type: :text, name: :reason, placeholder: 'Reason', required: true
          input type: :submit, value: 'Retry'
        end
      end
    end
  end
end

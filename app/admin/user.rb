# frozen_string_literal: true

ActiveAdmin.register User do
  actions :index, :show

  %i[suspend restore].each do |operation|
    member_action operation, method: :post do
      authorize! operation, resource
      status = operation == :suspend ? 'suspended' : 'active'
      Platform::ChangeStatus.new(actor: current_admin_user, target: resource, request_id: request.request_id)
                            .call(status:, reason: params.require(:reason))
      redirect_to resource_path, notice: I18n.t('saas.admin.account_updated')
    end
  end

  form do |f|
    f.inputs 'Details' do
      f.input :email
      f.input :first_name
      f.input :last_name
      f.input :username

      if f.object.new_record?
        f.input :password
        f.input :password_confirmation
      end
    end

    actions
  end

  index do
    selectable_column
    id_column
    column :email
    column :first_name
    column :last_name
    column :username
    column :status
    column :sign_in_count
    column :created_at
    column :updated_at

    actions
  end

  filter :id
  filter :email
  filter :username
  filter :first_name
  filter :last_name
  filter :created_at
  filter :updated_at

  show do
    attributes_table do
      row :id
      row :email
      row :first_name
      row :last_name
      row :username
      row :status
      row :sign_in_count
      row :created_at
      row :updated_at
    end
    if current_admin_user.super_admin?
      panel 'Change account status' do
        %w[suspend restore].each do |operation|
          form action: "/admin/users/#{resource.id}/#{operation}", method: :post do
            input type: :hidden, name: :authenticity_token, value: form_authenticity_token
            input type: :text, name: :reason, placeholder: 'Reason', required: true
            input type: :submit, value: operation.capitalize
          end
        end
      end
    end
  end
end

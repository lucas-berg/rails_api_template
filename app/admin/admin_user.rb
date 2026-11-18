# frozen_string_literal: true

ActiveAdmin.register AdminUser do
  actions :all, except: :destroy
  permit_params :email, :password, :password_confirmation, :role

  controller do
    before_action :require_operation_reason, only: %i[create update]
    around_action :audit_admin_user_write, only: %i[create update]

    private

    def require_operation_reason
      authorize! action_name.to_sym, AdminUser
      @operation_reason = params.require(:admin_user).require(:operation_reason)
    end

    def audit_admin_user_write
      AdminUser.transaction do
        yield
        next unless resource.persisted? && resource.errors.empty? && resource.saved_changes.any?

        record_admin_change
      end
    end

    def record_admin_change
      AuditEvent.record!(actor: current_admin_user, action: "admin_user.#{action_name}", target: resource,
                         request_id: request.request_id, reason: @operation_reason, metadata: { role: resource.role })
    end
  end

  index do
    selectable_column
    id_column
    column :email
    column :role
    column :current_sign_in_at
    column :sign_in_count
    column :created_at
    actions
  end

  filter :email
  filter :current_sign_in_at
  filter :sign_in_count
  filter :created_at

  form do |f|
    f.inputs 'Admin Details' do
      f.input :email
      f.input :role, as: :select, collection: AdminUser.roles.keys, include_blank: false
      f.input :password
      f.input :password_confirmation
      f.input :operation_reason, as: :string, required: true
    end
    f.actions
  end

  show do
    attributes_table do
      row :id
      row :email
      row :role
      row :sign_in_count
      row :created_at
      row :updated_at
    end
  end
end

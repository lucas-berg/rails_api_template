# frozen_string_literal: true

ActiveAdmin.register AuthSession do
  actions :index, :show
  filter :user_id
  filter :expires_at
  index do
    id_column
    column :user_id
    column :expires_at
    column :revoked_at
    column :last_used_at
    actions
  end
  show do
    attributes_table do
      row :user_id
      row :expires_at
      row :revoked_at
      row :last_used_at
      row :created_at
    end
  end
end

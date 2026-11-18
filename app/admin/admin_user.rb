# frozen_string_literal: true

ActiveAdmin.register AdminUser do
  actions :all, except: :destroy
  permit_params :email, :password, :password_confirmation, :role

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

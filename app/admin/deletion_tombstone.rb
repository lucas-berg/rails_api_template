# frozen_string_literal: true

ActiveAdmin.register DeletionTombstone do
  actions :index, :show
  config.filters = false
  index do
    id_column
    column :subject_type
    column :subject_id
    column :deleted_at
    actions
  end
  show do
    attributes_table do
      row :subject_type
      row :subject_id
      row :deleted_at
      row :created_at
    end
  end
end

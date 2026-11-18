# frozen_string_literal: true

ActiveAdmin.register DataExport do
  actions :index, :show
  filter :team_id
  filter :requested_by_id
  filter :status, as: :select, collection: %w[pending processing ready failed expired]
  index do
    id_column
    column :team_id
    column :requested_by_id
    column :status
    column :attempts
    column :expires_at
    column :failure_code
    actions
  end
  show do
    attributes_table do
      row :team_id
      row :requested_by_id
      row :status
      row :attempts
      row :expires_at
      row :failure_code
      row :created_at
    end
  end
end

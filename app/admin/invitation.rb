# frozen_string_literal: true

ActiveAdmin.register Invitation do
  actions :index, :show
  filter :team_id
  filter :normalized_email
  index do
    id_column
    column :team_id
    column :normalized_email
    column :role
    column :expires_at
    column :accepted_at
    column :revoked_at
    actions
  end
  show do
    attributes_table do
      row :team_id
      row :normalized_email
      row :role
      row :expires_at
      row :accepted_at
      row :revoked_at
    end
  end
end

# frozen_string_literal: true

ActiveAdmin.register Notification do
  actions :index, :show
  config.filters = false
  index do
    id_column
    column :user_id
    column :team_id
    column :kind
    column :read_at
    column :created_at
    actions
  end
end

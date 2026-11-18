# frozen_string_literal: true

ActiveAdmin.register Member do
  actions :index, :show
  filter :team_id
  filter :user_id
  filter :role, as: :select, collection: Member.roles.keys
  index do
    id_column
    column :team_id
    column :user_id
    column :role
    column :status
    actions
  end
end

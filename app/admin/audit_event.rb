# frozen_string_literal: true

ActiveAdmin.register AuditEvent do
  actions :index, :show
  filter :team_id
  filter :actor_type
  filter :actor_id
  filter :action
  filter :occurred_at
  index do
    id_column
    column :team_id
    column :actor_type
    column :actor_id
    column :action
    column :occurred_at
    actions
  end
end

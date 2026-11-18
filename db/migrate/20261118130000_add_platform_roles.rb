# frozen_string_literal: true

class AddPlatformRoles < ActiveRecord::Migration[8.1]
  def up
    add_column :admin_users, :role, :string, null: false, default: 'support'
    execute "UPDATE admin_users SET role = 'super_admin'"
    add_check_constraint :admin_users, "role IN ('super_admin', 'support')", name: 'admin_users_role_check'
  end

  def down
    remove_column :admin_users, :role
  end
end

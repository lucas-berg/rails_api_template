# frozen_string_literal: true

class CreateTeamCollaboration < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :preferences, :jsonb, default: {}, null: false

    create_teams
    create_members
    create_invitations
    create_audit_events
    add_foreign_key :mail_deliveries, :teams, on_delete: :nullify
  end

  private

  def create_teams
    create_table :teams do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :status, default: 'active', null: false
      t.string :timezone, default: 'UTC', null: false
      t.string :locale, default: 'en', null: false
      t.timestamps
    end
    add_index :teams, :slug, unique: true
    add_check_constraint :teams, "status IN ('active', 'suspended')", name: 'teams_status_allowed'
  end

  def create_members
    create_table :members do |t|
      t.references :team, null: false, foreign_key: true
      t.references :user, type: :integer, null: false, foreign_key: true
      t.string :role, default: 'member', null: false
      t.string :status, default: 'active', null: false
      t.timestamps
    end
    add_index :members, %i[team_id user_id], unique: true
    add_check_constraint :members, "role IN ('owner', 'admin', 'member', 'viewer')", name: 'members_role_allowed'
    add_check_constraint :members, "status IN ('active', 'removed')", name: 'members_status_allowed'
  end

  def create_invitations
    create_table :invitations do |t|
      t.references :team, null: false, foreign_key: true
      t.references :invited_by, type: :integer, null: false, foreign_key: { to_table: :users }
      t.string :normalized_email, null: false
      t.string :role, default: 'member', null: false
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :invitations, :token_digest, unique: true
    add_index :invitations, %i[team_id normalized_email], unique: true,
                                                          where: 'accepted_at IS NULL AND revoked_at IS NULL',
                                                          name: 'index_invitations_on_pending_email'
    add_check_constraint :invitations, "role IN ('admin', 'member', 'viewer')", name: 'invitations_role_allowed'
  end

  def create_audit_events
    create_table :audit_events do |t|
      t.references :team, foreign_key: true
      t.string :actor_type, null: false
      t.bigint :actor_id
      t.string :action, null: false
      t.string :target_type, null: false
      t.bigint :target_id
      t.string :request_id
      t.string :reason
      t.jsonb :metadata, default: {}, null: false
      t.datetime :occurred_at, null: false
      t.timestamps
    end
    add_index :audit_events, %i[team_id occurred_at id]
  end
end

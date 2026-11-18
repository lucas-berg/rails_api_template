# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20261118180000_remove_deletion_lifecycle')

# Separate identifiers make the historical row-ID and Active-Job-ID foreign keys explicit.
# rubocop:disable-next RSpec/MultipleMemoizedHelpers
RSpec.describe RemoveDeletionLifecycle do
  self.use_transactional_tests = false

  let(:connection) { ActiveRecord::Base.connection }
  let(:migration) { described_class.new }
  let(:process_id) { SecureRandom.uuid }
  let(:process_active_id) { SecureRandom.uuid }
  let(:legacy_id) { SecureRandom.uuid }
  let(:sweep_id) { SecureRandom.uuid }
  let(:mail_id) { SecureRandom.uuid }
  let(:deleted_at) { Time.utc(2025, 1, 2, 3, 4, 5) }
  let(:administrator) { AdminUser.new(role: 'super_admin') }

  around do |example|
    # Load current model metadata before switching to the explicit historical fixture tables.
    User.columns
    Team.columns
    administrator
    schema = "deletion_removal_#{SecureRandom.hex(6)}"
    previous_path = connection.schema_search_path
    connection.execute("CREATE SCHEMA #{connection.quote_table_name(schema)}")
    begin
      connection.schema_search_path = schema
      create_previous_schema
      example.run
    ensure
      connection.schema_search_path = previous_path
      connection.execute("DROP SCHEMA #{connection.quote_table_name(schema)} CASCADE")
    end
  end

  def create_previous_schema
    create_account_tables
    create_deletion_tables
    create_notification_tables
    create_job_tables
  end

  # These columns describe the old migration boundary, independent of application factories.
  # Users and teams intentionally repeat their own status and deletion marker columns.
  # :reek:DuplicateMethodCall
  # :reek:FeatureEnvy
  # :reek:TooManyStatements
  # rubocop:disable-next Metrics/AbcSize
  def create_account_tables
    connection.create_table(:users) do |table|
      table.string :status, default: 'active'
      table.string :uid
      table.string :email
      table.string :username
      table.integer :credentials_version, default: 4
      table.datetime :deleted_at
    end
    connection.create_table(:auth_sessions) do |table|
      table.references :user, foreign_key: true
      table.datetime :revoked_at
    end
    connection.create_table(:teams) do |table|
      table.string :status, default: 'active'
      table.string :name
      table.datetime :deleted_at
    end
    connection.add_check_constraint(:teams,
                                    "status IN ('active', 'suspended', 'deletion_pending', 'deleting', 'deleted')",
                                    name: 'teams_status_allowed')
  end

  # :reek:FeatureEnvy
  def create_deletion_tables
    connection.create_table(:deletion_requests) do |table|
      table.string :subject_type
      table.bigint :subject_id
      table.string :status
      table.string :stage
      table.references :requested_by, foreign_key: { to_table: :users }
    end
    connection.create_table(:deletion_tombstones) { |table| table.string :fingerprint }
  end

  def create_notification_tables
    connection.create_table(:notifications) { |table| table.string :kind }
    connection.create_table(:notification_deliveries) do |table|
      table.references :notification, foreign_key: true
    end
  end

  # Keep job identifiers distinct to exercise both GoodJob's row ID and Active Job ID references.
  # :reek:FeatureEnvy
  def create_job_tables
    connection.create_table(:good_jobs, id: :uuid) do |table|
      table.uuid :active_job_id, index: { unique: true }
      table.string :job_class
      table.jsonb :serialized_params
      table.datetime :finished_at
      table.datetime :locked_at
      table.uuid :locked_by_id
      table.uuid :retried_good_job_id
    end
    create_job_dependents
  end

  def create_job_dependents
    connection.create_table(:good_job_executions) do |table|
      table.uuid :active_job_id
      table.string :job_class
    end
    connection.add_foreign_key(:good_job_executions, :good_jobs, column: :active_job_id, primary_key: :active_job_id)
    connection.create_table(:good_job_concurrency_claims) { |table| table.uuid :job_id }
    connection.add_foreign_key(:good_job_concurrency_claims, :good_jobs, column: :job_id)
    connection.add_foreign_key(:good_jobs, :good_jobs, column: :retried_good_job_id)
  end

  def insert(table, attributes)
    columns = attributes.keys.map { |key| connection.quote_column_name(key) }.join(', ')
    values = attributes.values.map { |value| connection.quote(value) }.join(', ')
    connection.execute("INSERT INTO #{connection.quote_table_name(table)} (#{columns}) VALUES (#{values})")
  end

  # The three removed job formats and the retained retry link belong in one fixture.
  # rubocop:disable-next Metrics/AbcSize
  def seed_jobs
    insert(:good_jobs, id: process_id, active_job_id: process_active_id, job_class: 'ProcessDeletionJob')
    insert(:good_jobs, id: legacy_id, active_job_id: legacy_id,
                       serialized_params: { job_class: 'SendDeletionNoticeJob' }.to_json)
    insert(:good_jobs, id: sweep_id, active_job_id: sweep_id, job_class: 'SweepDeletionsJob',
                       finished_at: deleted_at, locked_at: deleted_at)
    insert(:good_jobs, id: mail_id, active_job_id: mail_id, job_class: 'SendMailDeliveryJob',
                       retried_good_job_id: process_id)
    seed_job_dependents
  end

  def seed_job_dependents
    insert(:good_job_executions, id: 1, active_job_id: process_active_id, job_class: 'ProcessDeletionJob')
    insert(:good_job_executions, id: 2, active_job_id: legacy_id)
    insert(:good_job_executions, id: 3, active_job_id: mail_id, job_class: 'SendMailDeliveryJob')
    insert(:good_job_executions, id: 4, active_job_id: mail_id, job_class: 'SweepDeletionsJob')
    insert(:good_job_concurrency_claims, id: 1, job_id: process_id)
    insert(:good_job_concurrency_claims, id: 2, job_id: legacy_id)
    insert(:good_job_concurrency_claims, id: 3, job_id: mail_id)
  end

  def seed_notifications
    insert(:notifications, id: 1, kind: 'deletion.account_requested')
    insert(:notifications, id: 2, kind: 'deletion.team_completed')
    insert(:notifications, id: 3, kind: 'password_changed')
    insert(:notification_deliveries, id: 1, notification_id: 1)
    insert(:notification_deliveries, id: 2, notification_id: 2)
    insert(:notification_deliveries, id: 3, notification_id: 3)
    insert(:deletion_tombstones, id: 1, fingerprint: 'historical-tombstone')
  end

  # Each row represents a historical state that must survive removal differently.
  # :reek:TooManyStatements
  def seed_users
    insert(:users, id: 1, uid: 'active-uid', email: 'active@example.com', username: 'Active account')
    insert(:users, id: 2, uid: 'pending-uid', email: 'pending@example.com', username: 'Pending account')
    insert(:users, id: 3, uid: 'frozen-uid', status: 'suspended', email: 'frozen@example.com')
    insert(:users, id: 4, uid: 'old-deleted-uid', status: 'suspended', deleted_at:)
    insert(:users, id: 5, uid: 'failed-before-freeze', email: 'retry@example.com')
    insert(:users, id: 6, uid: 'previous-tombstone', status: 'suspended', deleted_at:)
    insert(:deletion_requests, subject_type: 'User', subject_id: 2, status: 'pending', stage: 'requested')
    insert(:deletion_requests, subject_type: 'User', subject_id: 3, status: 'failed', stage: 'ledger')
    insert(:deletion_requests, subject_type: 'User', subject_id: 4, status: 'completed', stage: 'completed')
    insert(:deletion_requests, subject_type: 'User', subject_id: 5, status: 'failed', stage: 'requested')
    connection.execute('INSERT INTO auth_sessions (user_id) SELECT id FROM users')
  end

  # :reek:TooManyStatements
  def seed_teams
    insert(:teams, id: 1, name: 'Active team')
    insert(:teams, id: 2, name: 'Cooling team', status: 'deletion_pending')
    insert(:teams, id: 3, name: 'Deleting team', status: 'deleting')
    insert(:teams, id: 4, name: 'Failed irreversible team', status: 'suspended')
    insert(:teams, id: 5, name: 'Previously deleted team', status: 'deleted', deleted_at:)
    insert(:deletion_requests, subject_type: 'Team', subject_id: 2, status: 'pending', stage: 'requested')
    insert(:deletion_requests, subject_type: 'Team', subject_id: 3, status: 'processing', stage: 'records')
    insert(:deletion_requests, subject_type: 'Team', subject_id: 4, status: 'failed', stage: 'ledger')
  end

  def apply_migration
    migration.suppress_messages { connection.transaction { migration.up } }
  end

  it 'removes obsolete jobs and notification rows without breaking retained mail jobs or their foreign keys' do
    seed_jobs
    seed_notifications
    apply_migration

    expect(connection.select_values('SELECT id FROM good_jobs')).to eq([mail_id])
    expect(connection.select_value('SELECT retried_good_job_id FROM good_jobs')).to be_nil
    expect(connection.select_values('SELECT active_job_id FROM good_job_executions')).to eq([mail_id])
    expect(connection.select_values('SELECT job_id FROM good_job_concurrency_claims')).to eq([mail_id])
    expect(connection.select_values('SELECT kind FROM notifications')).to eq(['password_changed'])
    expect(connection.select_values('SELECT notification_id FROM notification_deliveries')).to eq([3])
    expect(connection.table_exists?(:deletion_requests)).to be(false)
    expect(connection.table_exists?(:deletion_tombstones)).to be(false)
  end

  it 'preserves account data and UIDs while making irreversible accounts unavailable and revoking their sessions' do
    seed_users
    before = connection.select_all('SELECT * FROM users ORDER BY id').to_a.index_by { |row| row.fetch('id') }
    apply_migration
    users = connection.select_all('SELECT * FROM users ORDER BY id').to_a.index_by { |row| row.fetch('id') }

    expect(users.values_at(1, 2, 5)).to eq(before.values_at(1, 2, 5))
    expect(users.fetch(3)).to include('status' => 'suspended', 'uid' => 'frozen-uid',
                                      'email' => 'frozen@example.com', 'credentials_version' => 5)
    expect(users.fetch(3).fetch('deleted_at')).to be_present
    expect(users.fetch(4).fetch('deleted_at')).to eq(deleted_at)
    expect(users.fetch(6)).to eq(before.fetch(6))
    revoked_users = connection.select_values(
      'SELECT user_id FROM auth_sessions WHERE revoked_at IS NOT NULL ORDER BY user_id'
    )
    expect(revoked_users).to eq([3, 4, 6])
    expect {
      Platform::ChangeStatus.new(actor: administrator, target: User.find(3), request_id: 'migration-check')
                            .call(status: 'active', reason: 'Must remain unavailable')
    }.to raise_error(Collaboration::Conflict) { |error| expect(error.code).to eq('deleted_record') }
  end

  it 'suspends cooling teams and permanently protects irreversible or already deleted teams' do
    seed_teams
    apply_migration
    teams = connection.select_all('SELECT * FROM teams ORDER BY id').to_a.index_by { |row| row.fetch('id') }

    expect(teams.fetch(1)).to include('status' => 'active', 'name' => 'Active team', 'deleted_at' => nil)
    expect(teams.fetch(2)).to include('status' => 'suspended', 'name' => 'Cooling team', 'deleted_at' => nil)
    expect(teams.values_at(3, 4).pluck('status')).to eq(%w[deleted deleted])
    expect(teams.values_at(3, 4).pluck('deleted_at')).to all(be_present)
    expect(teams.fetch(5)).to include('status' => 'deleted', 'deleted_at' => deleted_at)
    expect {
      Platform::ChangeStatus.new(actor: administrator, target: Team.find(3), request_id: 'migration-check')
                            .call(status: 'active', reason: 'Must remain unavailable')
    }.to raise_error(Collaboration::Conflict) { |error| expect(error.code).to eq('deleted_record') }
    expect {
      connection.execute("UPDATE teams SET status = 'deletion_pending' WHERE id = 1")
    }.to raise_error(ActiveRecord::StatementInvalid, /teams_status_allowed/)
  end

  it 'rolls back without removing data when an old serialized worker job is still claimed' do
    seed_users
    seed_teams
    seed_jobs
    seed_notifications
    connection.execute <<~SQL.squish
      UPDATE good_jobs SET locked_by_id = #{connection.quote(SecureRandom.uuid)}
      WHERE id = #{connection.quote(legacy_id)}
    SQL

    expect { apply_migration }.to raise_error(RuntimeError, /Stop old workers/)
    expect(connection.select_value('SELECT COUNT(*) FROM good_jobs')).to eq(4)
    expect(connection.select_value('SELECT COUNT(*) FROM good_job_executions')).to eq(4)
    expect(connection.select_value('SELECT COUNT(*) FROM good_job_concurrency_claims')).to eq(3)
    expect(connection.select_value('SELECT COUNT(*) FROM notifications')).to eq(3)
    expect(connection.select_value('SELECT COUNT(*) FROM notification_deliveries')).to eq(3)
    expect(connection.select_value('SELECT deleted_at FROM users WHERE id = 3')).to be_nil
    expect(connection.select_value('SELECT status FROM teams WHERE id = 2')).to eq('deletion_pending')
    expect(connection.table_exists?(:deletion_requests)).to be(true)
    expect(connection.table_exists?(:deletion_tombstones)).to be(true)
  end

  it 'does not claim that rolling back can restore removed lifecycle records' do
    expect { migration.down }.to raise_error(ActiveRecord::IrreversibleMigration, /backup/)
  end
end

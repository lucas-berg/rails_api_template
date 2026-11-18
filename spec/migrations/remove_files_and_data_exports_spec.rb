# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20261118170000_remove_files_and_data_exports')

RSpec.describe RemoveFilesAndDataExports do
  self.use_transactional_tests = false

  let(:connection) { ActiveRecord::Base.connection }
  let(:migration) { described_class.new }
  let(:removed_id) { SecureRandom.uuid }
  let(:legacy_id) { SecureRandom.uuid }
  let(:retained_id) { SecureRandom.uuid }

  around do |example|
    schema = "module_removal_#{SecureRandom.hex(6)}"
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
    connection.create_table(:documents)
    connection.create_table(:data_exports)
    connection.create_table(:users)
    connection.add_reference(:users, :avatar_document, foreign_key: { to_table: :documents })
    create_storage_tables
    create_notification_tables
    create_job_tables
    create_deletion_table
  end

  def create_deletion_table
    connection.create_table(:deletion_requests) { |table| table.string :stage }
    connection.add_check_constraint(:deletion_requests,
                                    "stage IN ('requested','ledger','files','exports','records','completed')",
                                    name: 'deletion_requests_stage_allowed')
  end

  # Keep the historical schema explicit, including separate blob references on both tables.
  # :reek:DuplicateMethodCall
  # :reek:FeatureEnvy
  def create_storage_tables
    connection.create_table(:active_storage_blobs) { |table| table.string :key }
    connection.create_table(:active_storage_variant_records) { |table| table.references :blob }
    connection.create_table(:active_storage_attachments) do |table|
      table.string :record_type
      table.bigint :record_id
      table.references :blob
    end
  end

  def create_notification_tables
    connection.create_table(:notifications) { |table| table.string :kind }
    connection.create_table(:notification_deliveries) do |table|
      table.references :notification, foreign_key: true
    end
  end

  # These historical columns belong to the isolated migration fixture, not current model factories.
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

  # Keep removed and retained records together so the migration boundary is visible in one fixture.
  # :reek:TooManyStatements
  def seed_removed_and_retained_rows
    insert(:documents, id: 1)
    insert(:data_exports, id: 1)
    insert(:users, id: 1, avatar_document_id: 1)
    insert(:active_storage_blobs, id: 1, key: 'retained-object-key')
    insert(:active_storage_variant_records, id: 1, blob_id: 1)
    insert(:active_storage_attachments, id: 1, record_type: 'Document', record_id: 1, blob_id: 1)
    insert(:active_storage_attachments, id: 2, record_type: 'DataExport', record_id: 1, blob_id: 1)
    insert(:active_storage_attachments, id: 3, record_type: 'OtherRecord', record_id: 1, blob_id: 1)
    insert(:notifications, id: 1, kind: 'export.ready')
    insert(:notifications, id: 2, kind: 'password_changed')
    insert(:notification_deliveries, id: 1, notification_id: 1)
    insert(:notification_deliveries, id: 2, notification_id: 2)
    connection.execute("INSERT INTO deletion_requests (stage) VALUES ('files'), ('exports'), ('ledger')")
    seed_jobs
  end

  def seed_jobs
    insert(:good_jobs, id: removed_id, active_job_id: removed_id, job_class: 'BuildDataExportJob')
    insert(:good_jobs, id: legacy_id, active_job_id: legacy_id,
                       serialized_params: { job_class: 'VerifyDocumentJob' }.to_json)
    insert(:good_jobs, id: retained_id, active_job_id: retained_id, job_class: 'SendMailDeliveryJob',
                       retried_good_job_id: removed_id)
    seed_job_dependents
  end

  def seed_job_dependents
    insert(:good_job_executions, id: 1, active_job_id: removed_id, job_class: 'BuildDataExportJob')
    insert(:good_job_executions, id: 2, active_job_id: legacy_id)
    insert(:good_job_executions, id: 3, active_job_id: retained_id, job_class: 'SendMailDeliveryJob')
    insert(:good_job_concurrency_claims, id: 1, job_id: removed_id)
    insert(:good_job_concurrency_claims, id: 2, job_id: retained_id)
  end

  def apply_migration
    migration.suppress_messages { connection.transaction { migration.up } }
  end

  it 'removes only obsolete metadata, respects job foreign keys and folds previous deletion stages' do
    seed_removed_and_retained_rows
    Tempfile.create('preserved-storage-object') do |file|
      file.write('private content retained outside this migration')
      file.flush
      apply_migration
      expect(File.read(file.path)).to eq('private content retained outside this migration')
    end

    expect(connection.table_exists?(:documents)).to be(false)
    expect(connection.table_exists?(:data_exports)).to be(false)
    expect(connection.column_exists?(:users, :avatar_document_id)).to be(false)
    stages = connection.select_values('SELECT stage FROM deletion_requests ORDER BY id')
    expect(stages).to eq(%w[records records ledger])
    expect(connection.select_values('SELECT key FROM active_storage_blobs')).to eq(['retained-object-key'])
    expect(connection.select_value('SELECT COUNT(*) FROM active_storage_variant_records')).to eq(1)
    expect(connection.select_values('SELECT record_type FROM active_storage_attachments')).to eq(['OtherRecord'])
    expect(connection.select_values('SELECT kind FROM notifications')).to eq(['password_changed'])
    expect(connection.select_values('SELECT notification_id FROM notification_deliveries')).to eq([2])
    expect(connection.select_values('SELECT id FROM good_jobs')).to eq([retained_id])
    expect(connection.select_value('SELECT retried_good_job_id FROM good_jobs')).to be_nil
    expect(connection.select_values('SELECT active_job_id FROM good_job_executions')).to eq([retained_id])
    expect(connection.select_values('SELECT job_id FROM good_job_concurrency_claims')).to eq([retained_id])
    expect {
      connection.execute("INSERT INTO deletion_requests (stage) VALUES ('files')")
    }.to raise_error(ActiveRecord::StatementInvalid, /deletion_requests_stage_allowed/)
  end

  it 'refuses a claimed old worker task before removing any records' do
    seed_removed_and_retained_rows
    connection.execute("UPDATE good_jobs SET locked_at = CURRENT_TIMESTAMP WHERE job_class = 'BuildDataExportJob'")
    expect { apply_migration }.to raise_error(RuntimeError, /Stop old workers/)
    expect(connection.select_value('SELECT COUNT(*) FROM good_jobs')).to eq(3)
    expect(connection.table_exists?(:documents)).to be(true)
    expect(connection.select_values('SELECT stage FROM deletion_requests ORDER BY id')).to eq(%w[files exports ledger])
  end

  it 'does not offer a rollback which falsely claims to restore removed business data' do
    expect { migration.down }.to raise_error(ActiveRecord::IrreversibleMigration, /backup/)
  end
end

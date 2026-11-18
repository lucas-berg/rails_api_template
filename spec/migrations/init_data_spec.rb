# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20261118190000_init_data')

RSpec.describe InitData do
  self.use_transactional_tests = false

  let(:connection) { ActiveRecord::Base.connection }
  let(:migration_context) { ActiveRecord::MigrationContext.new(Rails.root.join('db/migrate').to_s) }

  around do |example|
    schema = "init_data_#{SecureRandom.hex(6)}"
    previous_path = connection.schema_search_path
    connection.execute("CREATE SCHEMA #{connection.quote_table_name(schema)}")
    begin
      connection.schema_search_path = schema
      connection.schema_cache.clear!
      described_class.new.suppress_messages { example.run }
    ensure
      connection.schema_search_path = previous_path
      connection.schema_cache.clear!
      connection.execute("DROP SCHEMA #{connection.quote_table_name(schema)} CASCADE")
    end
  end

  def schema_dump
    output = StringIO.new
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection_pool, output)
    output.string
  end

  it 'creates the final schema without retired modules or credentials' do
    migration_context.migrate

    tables = connection.tables - %w[schema_migrations ar_internal_metadata]
    expect(tables.size).to eq(24)
    expect(tables).not_to include('documents', 'data_exports', 'deletion_requests', 'deletion_tombstones')
    expect(connection.column_exists?(:users, :tracing_api_key)).to be(false)
    expect(connection.column_exists?(:users, :avatar_document_id)).to be(false)
    expect(connection.foreign_key_exists?(:auth_sessions, :users)).to be(true)
    expect(migration_context.get_all_versions).to eq([20_261_118_190_000])
  end

  it 'can roll back a fresh installation and recreate the same schema' do
    migration_context.migrate
    initial_schema = schema_dump

    migration_context.rollback

    expect(connection.tables - %w[schema_migrations ar_internal_metadata]).to be_empty
    expect(migration_context.get_all_versions).to be_empty

    migration_context.migrate

    expect(schema_dump).to eq(initial_schema)
  end

  it 'skips the baseline on an existing database at the final historical version' do
    migration_context.migrate
    migration_context.schema_migration.create_version('20251013122411')
    connection.execute <<~SQL.squish
      INSERT INTO settings (key, value, created_at, updated_at)
      VALUES ('preserved', 'existing value', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
    initial_schema = schema_dump

    expect(migration_context.migrate).to be_empty
    expect(schema_dump).to eq(initial_schema)
    expect(connection.select_value("SELECT value FROM settings WHERE key = 'preserved'")).to eq('existing value')
  end
end

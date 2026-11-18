# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20261118190000_remove_tracing_api_key_from_users')

RSpec.describe RemoveTracingAPIKeyFromUsers do
  self.use_transactional_tests = false

  let(:connection) { ActiveRecord::Base.connection }
  let(:migration) { described_class.new }

  around do |example|
    schema = "tracing_key_removal_#{SecureRandom.hex(6)}"
    previous_path = connection.schema_search_path
    connection.execute("CREATE SCHEMA #{connection.quote_table_name(schema)}")
    begin
      connection.schema_search_path = schema
      create_users_table
      example.run
    ensure
      connection.schema_search_path = previous_path
      connection.execute("DROP SCHEMA #{connection.quote_table_name(schema)} CASCADE")
    end
  end

  # The fixture explicitly preserves the independent identity and email indexes.
  # :reek:FeatureEnvy
  def create_users_table
    connection.create_table(:users) do |table|
      table.string :uid, null: false
      table.string :email, null: false
      table.string :provider, default: 'email', null: false
      table.index :email, unique: true
      table.index %i[uid provider], unique: true
    end
  end

  def apply_migration
    migration.suppress_messages { connection.transaction { migration.up } }
  end

  it 'removes only the key and its unique index while preserving account data and unrelated tracing records' do
    connection.add_column(:users, :tracing_api_key, :string, null: false)
    connection.add_index(:users, :tracing_api_key, unique: true)
    connection.execute <<~SQL.squish
      INSERT INTO users (id, uid, email, tracing_api_key)
      VALUES (7, 'stable-user-uid', 'account@example.com', 'synthetic-fixture-key')
    SQL
    connection.create_table(:tracing_events) do |table|
      table.references :user, foreign_key: true
      table.string :name
    end
    connection.execute("INSERT INTO tracing_events (id, user_id, name) VALUES (1, 7, 'retained-event')")

    apply_migration

    expect(connection.columns(:users).map(&:name)).to eq(%w[id uid email provider])
    expect(connection.select_one('SELECT * FROM users')).to eq(
      'id' => 7, 'uid' => 'stable-user-uid', 'email' => 'account@example.com', 'provider' => 'email'
    )
    expect(connection.index_exists?(:users, :tracing_api_key)).to be(false)
    expect(connection.index_exists?(:users, :email, unique: true)).to be(true)
    expect(connection.index_exists?(:users, %i[uid provider], unique: true)).to be(true)
    expect(connection.select_one('SELECT * FROM tracing_events')).to eq(
      'id' => 1, 'user_id' => 7, 'name' => 'retained-event'
    )
    expect(connection.foreign_key_exists?(:tracing_events, :users)).to be(true)
  end

  it 'succeeds when a fresh database never had the key column' do
    connection.execute("INSERT INTO users (id, uid, email) VALUES (9, 'fresh-user-uid', 'fresh@example.com')")

    expect { apply_migration }.not_to raise_error

    expect(connection.select_one('SELECT * FROM users')).to eq(
      'id' => 9, 'uid' => 'fresh-user-uid', 'email' => 'fresh@example.com', 'provider' => 'email'
    )
    expect(connection.index_exists?(:users, :email, unique: true)).to be(true)
    expect(connection.index_exists?(:users, %i[uid provider], unique: true)).to be(true)
  end

  it 'does not claim that a rollback can recover discarded credentials' do
    expect { migration.down }.to raise_error(ActiveRecord::IrreversibleMigration)
  end
end

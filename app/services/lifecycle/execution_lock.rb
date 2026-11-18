# frozen_string_literal: true

module Lifecycle
  module ExecutionLock
    def self.with(namespace:, id:)
      ApplicationRecord.connection_pool.with_connection do |connection|
        arguments = [Integer(namespace), Integer(id)]
        lock_query = ApplicationRecord.sanitize_sql_array(['SELECT pg_try_advisory_lock(?, ?)', *arguments])
        unlock_query = ApplicationRecord.sanitize_sql_array(['SELECT pg_advisory_unlock(?, ?)', *arguments])
        locked = connection.select_value(lock_query)
        next false unless locked

        begin
          yield
        ensure
          connection.execute(unlock_query)
        end
      end
    end
  end
end

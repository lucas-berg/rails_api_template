# frozen_string_literal: true

module Lifecycle
  module MembershipLock
    def self.with_user(user, &)
      with_users([user], &)
    end

    def self.with_users(users)
      ApplicationRecord.transaction do
        users.sort_by(&:id).each do |user|
          # A separate PostgreSQL advisory namespace avoids collisions with other application locks.
          query = ApplicationRecord.sanitize_sql_array(['SELECT pg_advisory_xact_lock(72124, ?)', Integer(user.id)])
          ApplicationRecord.connection.execute(query)
          user.reload
        end
        yield
      end
    end
  end
end

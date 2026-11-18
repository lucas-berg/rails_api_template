# frozen_string_literal: true

namespace :data do
  namespace :deletions do
    desc 'Export durable deletion tombstones to the independently backed-up deletion ledger directory'
    task export: :environment do
      DeletionTombstone.find_each { |record| Lifecycle::DeletionLedger.write!(record.ledger_entry) }
    end

    desc 'Reapply deletion ledger entries after database restore, before reopening application traffic'
    task replay: :environment do
      Lifecycle::ReplayDeletions.call
    end
  end
end

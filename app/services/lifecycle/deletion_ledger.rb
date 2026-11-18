# frozen_string_literal: true

module Lifecycle
  module DeletionLedger
    def self.directory
      value = ENV['DELETION_LEDGER_PATH'].presence
      raise 'DELETION_LEDGER_PATH must point to separately backed-up storage' if Rails.env.production? && !value

      Pathname.new(value || Rails.root.join('storage', 'deletion-ledger').to_s)
    end

    def self.write!(entry)
      uuid = entry.fetch('request_uuid')
      raise ArgumentError, 'Invalid deletion identifier' unless uuid.match?(/\A[0-9a-f-]{36}\z/)

      FileUtils.mkdir_p(directory, mode: 0o700)
      path = directory.join("#{uuid}.json")
      atomic_write(path, entry)
      File.open(directory, File::RDONLY, &:fsync)
      path
    end

    def self.atomic_write(path, entry)
      Tempfile.create(['ledger-', '.tmp'], directory, mode: File::RDWR, perm: 0o600) do |file|
        file.write(JSON.generate(entry))
        file.flush
        file.fsync
        File.rename(file.path, path)
      end
    end

    def self.entries
      directory.glob('*.json').map do |path|
        entry = JSON.parse(path.read)
        raise ArgumentError, "Unsupported ledger version in #{path.basename}" unless entry['version'] == 1

        entry
      end
    end

    def self.subject(entry)
      model = { 'User' => User, 'Team' => Team }.fetch(entry.fetch('subject_type'))
      record = model.find_by(id: entry.fetch('subject_id'))
      return unless record
      return record if DeletionTombstone.fingerprint(record) == entry.fetch('fingerprint')

      raise ArgumentError, 'Deletion ledger fingerprint does not match the restored record'
    end
  end
end

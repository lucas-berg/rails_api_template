# frozen_string_literal: true

module DataExports
  class Snapshot
    def initialize(team)
      @team = team
    end

    def write(io)
      @io = io
      write_header
      write_members
      write_audit
      write_documents
      @io.write('}')
      @io.flush
      @io.rewind
    end

    private

    def write_header
      @io.write('{"version":1,"file_contents_included":false,"team":')
      @io.write(JSON.generate(SaasPresenter.team(@team)))
    end

    def write_members
      write_records('members', @team.active_members.includes(:user)) { |record| SaasPresenter.member(record) }
    end

    def write_audit
      write_records('audit_events', @team.audit_events) { |record| SaasPresenter.audit_event(record) }
    end

    def write_documents
      write_records('documents', Document.where(team: @team)) do |record|
        record.attributes.slice('id', 'original_filename', 'verified_content_type', 'byte_size', 'status', 'created_at')
      end
    end

    def write_records(key, relation)
      @io.write(",\"#{key}\":[")
      first = true
      relation.find_each do |record|
        @io.write(',') unless first
        first = false
        @io.write(JSON.generate(yield(record)))
        raise RangeError, 'Export exceeds size limit' if @io.size > maximum_bytes
      end
      @io.write(']')
    end

    def maximum_bytes
      Integer(ENV.fetch('MAX_EXPORT_BYTES', 50.megabytes.to_s)).clamp(1, 500.megabytes)
    end
  end
end

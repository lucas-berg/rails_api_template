# frozen_string_literal: true

module API
  module V1
    class DataExportsController < TeamContextController
      def index
        authorize!(:audit, @team)
        render_collection(DataExport.where(team: @team, requested_by: current_user), &:presentation)
      end

      def show
        render_data(authorized_export.presentation)
      end

      def create
        export = DataExports::Create.new(**operation_options).call
        response.set_header('Location', "/api/v1/teams/#{@team.id}/exports/#{export.id}")
        render_data(export.presentation, status: :accepted)
      end

      def download
        export = authorized_export
        unless export.available?
          raise Collaboration::Conflict.new('export_unavailable',
                                            'The export is not ready or has expired')
        end

        stream_export(export)
      end

      private

      # Maps the authorized private blob to response headers and a bounded-memory stream.
      # :reek:FeatureEnvy
      def stream_export(export)
        blob = export.file.blob
        send_file_headers!(filename: "team-#{@team.id}-export.json", type: 'application/json',
                           disposition: 'attachment')
        response.headers.merge!('Content-Length' => blob.byte_size.to_s,
                                'Cache-Control' => 'private, no-store', 'X-Content-Type-Options' => 'nosniff')
        self.response_body = Enumerator.new { |output| blob.download { |chunk| output << chunk } }
      end

      def authorized_export
        export = DataExport.where(team: @team, requested_by: current_user).find(params.expect(:id))
        raise Authorization::Forbidden unless DataExportPolicy.new(current_user, export, @team).allowed?(:read)

        export
      end
    end
  end
end

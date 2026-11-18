# frozen_string_literal: true

module API
  module V1
    # :reek:FeatureEnvy -- Maps authorized file metadata to an explicitly private HTTP response.
    class FilesController < TeamContextController
      def index
        authorize!(:read, @team)
        render_collection(Document.where(team: @team).visible) { |document| DocumentPresenter.call(document) }
      end

      def show
        document = find_document
        authorize!(:read, document)
        render_data(DocumentPresenter.call(document))
      end

      def download
        serve_file(inline: false)
      end

      def preview
        serve_file(inline: true)
      end

      def destroy
        Documents::Remove.new(**operation_options).call(params[:id])
        head :no_content
      end

      private

      def find_document
        Document.where(team: @team).with_attached_file.find(params.expect(:id))
      end

      def serve_file(inline:)
        document = find_document
        authorize!(inline ? :preview : :download, document)
        validate_download!(document, inline:)
        prepare_headers(document, inline:)
        blob = document.file.blob
        self.response_body = Enumerator.new { |output| blob.download { |chunk| output << chunk } }
      end

      # :reek:ControlParameter -- Inline rendering has a stricter image-only allowlist.
      def validate_download!(document, inline:)
        unless document.ready? && document.file.attached?
          raise Collaboration::Conflict.new('file_unavailable', 'This file is not available for download')
        end
        return unless inline && !document.image?

        raise Collaboration::Conflict.new('preview_unavailable', 'Only verified images can be previewed')
      end

      # :reek:ControlParameter -- Only the trusted controller action chooses the disposition.
      def prepare_headers(document, inline:)
        disposition = ActionDispatch::Http::ContentDisposition.format(
          disposition: inline ? 'inline' : 'attachment', filename: document.original_filename
        )
        response.headers.merge!('Content-Type' => document.verified_content_type,
                                'Content-Length' => document.byte_size.to_s, 'Content-Disposition' => disposition,
                                'Cache-Control' => 'private, no-store', 'X-Content-Type-Options' => 'nosniff',
                                'Content-Security-Policy' => "default-src 'none'; sandbox")
      end
    end
  end
end

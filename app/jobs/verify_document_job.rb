# frozen_string_literal: true

class VerifyDocumentJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 5 do |job, _exception|
    Documents::Verify.reject!(job.arguments.first, 'verification_unavailable')
  end

  def perform(document_id)
    Documents::Verify.call(document_id)
  end

  private

  # The worker reconstructs correlation fields from its trusted document record.
  # :reek:FeatureEnvy
  def execution_context
    document = Document.find_by(id: arguments.first)
    return {} unless document

    { user: document.uploader, team: document.team }
  end
end

# frozen_string_literal: true

class VerifyDocumentJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 5 do |job, _exception|
    Documents::Verify.reject!(job.arguments.first, 'verification_unavailable')
  end

  def perform(document_id)
    Documents::Verify.call(document_id)
  end
end

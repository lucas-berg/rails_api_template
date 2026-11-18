# frozen_string_literal: true

class LifecycleMailer < ApplicationMailer
  def deletion_completed(deletion_id)
    @deletion = DeletionRequest.find(deletion_id)
    mail(to: @deletion.recipient)
  end
end

# frozen_string_literal: true

class NotificationMailer < ApplicationMailer
  def notice(notification)
    content = notification.localized_content
    mail(to: notification.user_email, subject: content.fetch('title')) do |format|
      format.text { render plain: content.fetch('body') }
    end
  end
end

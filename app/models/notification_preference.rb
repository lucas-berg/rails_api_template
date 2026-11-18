# frozen_string_literal: true

class NotificationPreference < ApplicationRecord
  BOOLEAN_VALUES = [true, false].freeze

  belongs_to :user

  validates :activity_in_app, :activity_email, inclusion: { in: BOOLEAN_VALUES }

  def self.for(user)
    find_by(user_id: user.id) || new(user: user)
  end

  def allows?(category, channel)
    presentation.fetch(:"#{category}_#{channel}", false)
  end

  def presentation
    { activity_in_app:, activity_email:, security_in_app: true, security_email: true }
  end
end

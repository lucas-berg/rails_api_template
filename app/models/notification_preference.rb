# frozen_string_literal: true

# == Schema Information
#
# Table name: notification_preferences
#
#  id              :bigint           not null, primary key
#  activity_email  :boolean          default(FALSE), not null
#  activity_in_app :boolean          default(TRUE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :integer          not null
#
# Indexes
#
#  index_notification_preferences_on_user_id  (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
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

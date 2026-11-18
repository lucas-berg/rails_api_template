# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  allow_password_change  :boolean          default(FALSE), not null
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  credentials_version    :integer          default(0), not null
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :inet
#  deleted_at             :datetime
#  email                  :string
#  encrypted_password     :string           default(""), not null
#  first_name             :string           default("")
#  last_name              :string           default("")
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :inet
#  preferences            :jsonb            not null
#  provider               :string           default("email"), not null
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  sign_in_count          :integer          default(0), not null
#  status                 :string           default("active"), not null
#  tokens                 :json
#  uid                    :string           default(""), not null
#  unconfirmed_email      :string
#  username               :string           default("")
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_uid_and_provider      (uid,provider) UNIQUE
#

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :jwt_authenticatable,
         :recoverable, :trackable, :validatable, :confirmable, jwt_revocation_strategy: AuthSession

  include UserAuthentication

  has_many :members, dependent: :restrict_with_error
  has_many :active_members, -> { active }, class_name: 'Member', dependent: :restrict_with_error, inverse_of: :user
  has_many :teams, through: :active_members
  has_many :notifications, dependent: :restrict_with_error
  has_one :notification_preference, dependent: :restrict_with_error

  validates :uid, uniqueness: { scope: :provider }
  validate :valid_preferences

  before_validation :init_uid
  before_update :sync_confirmed_uid

  PUBLIC_ATTRIBUTES = %w[id email first_name last_name username created_at updated_at provider uid].freeze

  def self.ransackable_attributes(_auth_object = nil)
    %w[id email username status]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  def self.from_social_provider(provider, user_params)
    attributes = user_params.with_indifferent_access
    uid = attributes[:id].presence || attributes.fetch(:uid)
    find_or_create_by!(provider:, uid:) do |user|
      user.password = Devise.friendly_token[0, 20]
      user.assign_attributes attributes.slice(:email, :username, :first_name, :last_name)
    end
  end

  def serializable_hash(options = nil)
    super(options.to_h.merge(only: PUBLIC_ATTRIBUTES, methods: [], include: []))
  end

  def full_name
    return username if first_name.blank?

    "#{first_name} #{last_name}"
  end

  # A caller supplies its authorized team to resolve the preference hierarchy.
  # :reek:ControlParameter
  def effective_preferences(team: nil)
    defaults = { 'locale' => team&.locale || 'en', 'timezone' => team&.timezone || 'UTC' }
    defaults.merge(preferences)
  end

  private

  def valid_preferences
    return errors.add(:preferences, 'must be an object') unless preferences.is_a?(Hash)

    errors.add(:preferences, 'contains unknown fields') if (preferences.keys - %w[locale timezone]).any?
    validate_preferred_locale
    validate_preferred_timezone
  end

  def validate_preferred_locale
    return unless preferences.key?('locale') && Team::LOCALES.exclude?(preferences['locale'])

    errors.add(:preferences, 'locale is not supported')
  end

  def validate_preferred_timezone
    return unless preferences.key?('timezone')

    timezone = preferences['timezone']
    errors.add(:preferences, 'timezone is not valid') unless timezone.is_a?(String) && ActiveSupport::TimeZone[timezone]
  end

  def init_uid
    return unless provider == 'email'

    self.uid = email if uid.blank?
  end

  def sync_confirmed_uid
    return unless provider == 'email' && will_save_change_to_email? && uid == email_in_database

    self.uid = email
  end
end

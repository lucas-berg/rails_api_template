# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  allow_password_change  :boolean          default(FALSE), not null
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :inet
#  email                  :string
#  encrypted_password     :string           default(""), not null
#  first_name             :string           default("")
#  last_name              :string           default("")
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :inet
#  provider               :string           default("email"), not null
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  sign_in_count          :integer          default(0), not null
#  tokens                 :json
#  uid                    :string           default(""), not null
#  username               :string           default("")
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
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
  include TeamMemberships

  validates :uid, uniqueness: { scope: :provider }

  before_validation :init_uid
  before_update :sync_confirmed_uid

  PUBLIC_ATTRIBUTES = %w[id email first_name last_name username created_at updated_at provider uid].freeze

  RANSACK_ATTRIBUTES = %w[id email first_name last_name username sign_in_count current_sign_in_at
                          last_sign_in_at current_sign_in_ip last_sign_in_ip provider uid
                          created_at updated_at].freeze

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

  private

  def init_uid
    return unless provider == 'email'

    self.uid = email if uid.blank?
  end

  def sync_confirmed_uid
    return unless provider == 'email' && will_save_change_to_email? && uid == email_in_database

    self.uid = email
  end
end

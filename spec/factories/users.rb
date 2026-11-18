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

FactoryBot.define do
  factory :user do
    email    { Faker::Internet.unique.email }
    password { Faker::Internet.password(min_length: 8) }
    username { Faker::Internet.unique.user_name }
    uid      { Faker::Internet.uuid }
    confirmed_at { Time.current }

    trait :unconfirmed do
      confirmed_at { nil }
    end
  end
end

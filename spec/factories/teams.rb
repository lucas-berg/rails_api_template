# frozen_string_literal: true

# == Schema Information
#
# Table name: teams
#
#  id         :bigint           not null, primary key
#  deleted_at :datetime
#  locale     :string           default("en"), not null
#  name       :string           not null
#  slug       :string           not null
#  status     :string           default("active"), not null
#  timezone   :string           default("UTC"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_teams_on_slug  (slug) UNIQUE
#
FactoryBot.define do
  factory :team do
    sequence(:name) { |n| "Team #{n}" }
  end

  factory :member do
    team
    user
    role { 'member' }

    trait :owner do
      role { 'owner' }
    end

    trait :admin do
      role { 'admin' }
    end

    trait :viewer do
      role { 'viewer' }
    end
  end

  factory :invitation do
    team
    invited_by factory: :user
    sequence(:normalized_email) { |n| "invite-#{n}@example.com" }
    role { 'member' }
    token_digest { Digest::SHA256.hexdigest(SecureRandom.urlsafe_base64(32)) }
    expires_at { 7.days.from_now }
  end
end

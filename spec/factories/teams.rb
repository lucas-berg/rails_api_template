# frozen_string_literal: true

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

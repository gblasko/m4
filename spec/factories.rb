FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "Marina #{n}" }
    sequence(:slug) { |n| "marina-#{n}" }
  end

  factory :user do
    organization
    sequence(:name) { |n| "User #{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    role { :customer }
    is_active { true }

    trait :manager do
      role { :manager }
    end
    trait :helper do
      role { :helper }
    end
    trait :customer do
      role { :customer }
    end
    trait :with_phone do
      sequence(:phone) { |n| "555-000-#{format('%04d', n)}" }
    end
  end

  factory :location do
    organization
    sequence(:name) { |n| "Loc #{n}" }
    sequence(:slug) { |n| "loc-#{n}" }
    timezone { "America/Chicago" }
    soft_cap_per_hour { 6 }
    is_active { true }

    after(:create) do |loc|
      (0..6).each do |d|
        loc.location_hours.create!(day_of_week: d, open_time: "07:00", close_time: "18:00", closed: false)
      end
    end
  end

  factory :slip do
    location
    sequence(:label) { |n| "S-#{n}" }
    slip_type { "in_water" }
    is_active { true }
  end

  factory :boat do
    association :owner, factory: [:user, :customer]
    location { owner.organization.locations.first || create(:location, organization: owner.organization) }
    sequence(:name) { |n| "Boat #{n}" }
    storage_type { "in_water" }
  end

  factory :request_type do
    organization
    sequence(:name) { |n| "Type #{n}" }
    sequence(:slug) { |n| "type-#{n}" }
    applicable_storage_types { %w[dry in_water] }
    color { "#2563eb" }
    is_active { true }
  end

  factory :request do
    boat
    customer { boat.owner }
    location { boat.location }
    request_type {
      RequestType.find_by(organization_id: boat.owner.organization_id) ||
        create(:request_type, organization: boat.owner.organization)
    }
    scheduled_for { 2.hours.from_now.change(min: 0) }
    status { "to_do" }
  end
end

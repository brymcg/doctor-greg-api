FactoryBot.define do
  factory :message do
    conversation { nil }
    role { "MyString" }
    content { "MyText" }
    metadata { "" }
    created_at { "2025-07-19 03:16:45" }
  end
end

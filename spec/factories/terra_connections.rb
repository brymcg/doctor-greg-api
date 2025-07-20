FactoryBot.define do
  factory :terra_connection do
    user { nil }
    provider { "MyString" }
    terra_user_id { "MyString" }
    reference_id { "MyString" }
    status { "MyString" }
    connected_at { "2025-07-19 03:00:52" }
    metadata { "MyText" }
  end
end

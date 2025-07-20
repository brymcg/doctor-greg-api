FactoryBot.define do
  factory :terra_health_datum do
    user { nil }
    terra_connection { nil }
    data_type { "MyString" }
    provider { "MyString" }
    recorded_at { "2025-07-19 03:05:05" }
    value { "9.99" }
    unit { "MyString" }
    metadata { "MyText" }
    raw_data { "" }
  end
end

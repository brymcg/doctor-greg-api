class AddHealthAttributesToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :date_of_birth, :date
    add_column :users, :height_cm, :integer
    add_column :users, :weight_kg, :decimal
    add_column :users, :activity_level, :string
    add_column :users, :biological_sex, :string
    add_column :users, :time_zone, :string
    add_column :users, :units_preference, :string
    add_column :users, :onboarded_at, :datetime
  end
end

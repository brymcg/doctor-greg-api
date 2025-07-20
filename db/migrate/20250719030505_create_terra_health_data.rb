class CreateTerraHealthData < ActiveRecord::Migration[7.1]
  def change
    create_table :terra_health_data do |t|
      t.references :user, null: false, foreign_key: true
      t.references :terra_connection, null: false, foreign_key: true
      t.string :data_type
      t.string :provider
      t.datetime :recorded_at
      t.decimal :value
      t.string :unit
      t.text :metadata
      t.jsonb :raw_data

      t.timestamps
    end
  end
end

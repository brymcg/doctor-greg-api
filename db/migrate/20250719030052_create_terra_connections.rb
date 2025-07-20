class CreateTerraConnections < ActiveRecord::Migration[7.1]
  def change
    create_table :terra_connections do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider
      t.string :terra_user_id
      t.string :reference_id
      t.string :status
      t.datetime :connected_at
      t.text :metadata

      t.timestamps
    end
  end
end

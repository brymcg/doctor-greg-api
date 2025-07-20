class AddIndexesToTerraHealthData < ActiveRecord::Migration[7.1]
  def change
    # Composite index for finding data by user, type, and date range
    add_index :terra_health_data, [:user_id, :data_type, :recorded_at], 
              name: 'index_terra_health_data_on_user_type_date'
    
    # Index for finding data by provider and date (for deduplication)
    add_index :terra_health_data, [:provider, :recorded_at], 
              name: 'index_terra_health_data_on_provider_date'
    
    # Index for finding recent data across all users (for admin/monitoring)
    add_index :terra_health_data, :recorded_at
    
    # Index for finding data by connection and date (for connection-specific queries)
    add_index :terra_health_data, [:terra_connection_id, :recorded_at], 
              name: 'index_terra_health_data_on_connection_date'
    
    # Partial index for only connected terra connections (most common query)
    add_index :terra_connections, [:user_id, :status], 
              where: "status = 'connected'",
              name: 'index_terra_connections_on_user_active'
    
    # Index for finding connections by provider
    add_index :terra_connections, :provider
  end
end

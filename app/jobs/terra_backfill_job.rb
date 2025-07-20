class TerraBackfillJob < ApplicationJob
  queue_as :default

  def perform(user_id, terra_connection_id)
    user = User.find(user_id)
    terra_connection = TerraConnection.find(terra_connection_id)
    terra_service = TerraService.new

    Rails.logger.info "Starting Terra backfill for user #{user_id}, connection #{terra_connection_id}"

    # Backfill last 1 year of data for comprehensive health insights
    start_date = 1.year.ago.to_date
    end_date = Date.current

    begin
      # Get body data (weight, body fat, etc.)
      body_response = terra_service.get_body_data(terra_connection.terra_user_id, start_date, end_date)
      process_backfill_data(user, terra_connection, 'body', body_response)

      # Get daily data (steps, calories, distance, etc.)
      daily_response = terra_service.get_daily_data(terra_connection.terra_user_id, start_date, end_date)
      process_backfill_data(user, terra_connection, 'daily', daily_response)

      # Get sleep data
      sleep_response = terra_service.get_sleep_data(terra_connection.terra_user_id, start_date, end_date)
      process_backfill_data(user, terra_connection, 'sleep', sleep_response)
      
      # Get activity data for comprehensive workout history
      activity_response = terra_service.get_activity_data(terra_connection.terra_user_id, start_date, end_date)
      process_backfill_data(user, terra_connection, 'activity', activity_response)

      Rails.logger.info "Completed Terra backfill for user #{user_id} (#{(end_date - start_date).to_i} days)"

    rescue StandardError => e
      Rails.logger.error "Terra backfill failed for user #{user_id}: #{e.message}"
      terra_connection.update!(status: 'error', metadata: { error: e.message })
      raise e
    end
  end

  private

  def process_backfill_data(user, terra_connection, data_type, response)
    return unless response && !response.key?('error')

    data_array = response['data'] || []
    
    data_array.each do |data_point|
      # Skip if we already have this data point
      next if data_exists?(user, terra_connection, data_type, data_point)

      TerraHealthDatum.create!(
        user: user,
        terra_connection: terra_connection,
        data_type: data_type,
        provider: terra_connection.provider,
        recorded_at: parse_timestamp(data_point['ts_utc']),
        raw_data: data_point,
        metadata: {
          source: 'backfill',
          backfilled_at: Time.current
        }
      )
    end

    Rails.logger.info "Backfilled #{data_array.length} #{data_type} records for user #{user.id}"
  end

  def data_exists?(user, terra_connection, data_type, data_point)
    timestamp = parse_timestamp(data_point['ts_utc'])
    return false unless timestamp

    user.terra_health_data
        .where(
          terra_connection: terra_connection,
          data_type: data_type,
          recorded_at: timestamp
        ).exists?
  end

  def parse_timestamp(timestamp)
    Time.parse(timestamp) if timestamp.present?
  rescue StandardError => e
    Rails.logger.error "Failed to parse timestamp #{timestamp}: #{e.message}"
    Time.current
  end
end 
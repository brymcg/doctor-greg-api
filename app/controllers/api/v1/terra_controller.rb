class Api::V1::TerraController < Api::V1::BaseController
  before_action :require_authentication!

  def auth_url
    providers = params[:providers] # Can be array or single provider
    
    terra_service = TerraService.new
    result = terra_service.generate_widget_session(current_user.id, providers)

    if result['status'] == 'success' && result['url']
      render json: {
        session_id: result['session_id'],
        widget_url: result['url'],
        expires_in: result['expires_in'],
        message: "Click the widget URL to connect your health data providers"
      }
    else
      render json: { 
        error: 'Failed to generate widget session',
        details: result 
      }, status: :unprocessable_entity
    end
  end

  def connect
    provider = params[:provider]&.downcase
    auth_code = params[:auth_code] # If using auth code flow
    
    unless valid_provider?(provider&.upcase)
      return render json: { error: 'Invalid provider' }, status: :bad_request
    end

    # Check if connection already exists
    existing_connection = current_user.terra_connections.find_by(provider: provider)
    
    if existing_connection&.connected?
      render json: {
        success: true,
        message: "#{provider.humanize} is already connected",
        connection: format_connection(existing_connection)
      }
    else
      # For most providers, the connection happens via webhook after auth_url redirect
      # This endpoint can be used to check connection status
      render json: {
        success: false,
        message: "Connection not yet established. Please complete the authentication flow.",
        provider: provider
      }
    end
  end

  def user_data
    data_type = params[:data_type] || 'all'
    start_date = params[:start_date] ? Date.parse(params[:start_date]) : 7.days.ago.to_date
    end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.current
    
    # Get user's Terra connections
    connections = current_user.terra_connections.active
    
    if connections.empty?
      return render json: {
        error: 'No active Terra connections found',
        message: 'Please connect a health data provider first'
      }, status: :not_found
    end

    case data_type
    when 'summary'
      render json: build_data_summary(connections, start_date, end_date)
    when 'daily'
      render json: get_daily_data_for_user(connections, start_date, end_date)
    when 'sleep'
      render json: get_sleep_data_for_user(connections, start_date, end_date)
    when 'body'
      render json: get_body_data_for_user(connections, start_date, end_date)
    when 'all'
      render json: get_all_data_for_user(connections, start_date, end_date)
    else
      render json: { error: 'Invalid data type' }, status: :bad_request
    end
  end

  def connections
    user_connections = current_user.terra_connections.includes(:terra_health_data)
    
    render json: {
      connections: user_connections.map { |conn| format_connection(conn) },
      total_connections: user_connections.count,
      active_connections: user_connections.active.count
    }
  end

  def disconnect
    provider = params[:provider]&.downcase
    
    unless valid_provider?(provider&.upcase)
      return render json: { error: 'Invalid provider' }, status: :bad_request
    end

    connection = current_user.terra_connections.find_by(provider: provider)
    
    unless connection
      return render json: { error: 'Connection not found' }, status: :not_found
    end

    # Deauthenticate with Terra
    terra_service = TerraService.new
    result = terra_service.deauthenticate_user(connection.terra_user_id)
    
    # Update local connection status
    connection.disconnect!
    
    render json: {
      success: true,
      message: "#{provider.humanize} disconnected successfully",
      provider: provider
    }
  end

  private

  def valid_provider?(provider)
    %w[WHOOP FITBIT GARMIN OURA POLAR STRAVA WITHINGS].include?(provider)
  end

  def format_connection(connection)
    {
      id: connection.id,
      provider: connection.provider,
      status: connection.status,
      connected_at: connection.connected_at,
      terra_user_id: connection.terra_user_id,
      data_count: connection.terra_health_data.count,
      latest_data: connection.terra_health_data.recent.first&.recorded_at
    }
  end

  def build_data_summary(connections, start_date, end_date)
    {
      date_range: "#{start_date} to #{end_date}",
      connections: connections.count,
      data_summary: {
        total_records: current_user.terra_health_data.where(recorded_at: start_date..end_date).count,
        daily_records: current_user.terra_health_data.where(data_type: 'daily', recorded_at: start_date..end_date).count,
        sleep_records: current_user.terra_health_data.where(data_type: 'sleep', recorded_at: start_date..end_date).count,
        body_records: current_user.terra_health_data.where(data_type: 'body', recorded_at: start_date..end_date).count,
        latest_sync: current_user.terra_health_data.maximum(:created_at)
      }
    }
  end

  def get_daily_data_for_user(connections, start_date, end_date)
    daily_data = current_user.terra_health_data
                            .where(data_type: 'daily', recorded_at: start_date..end_date)
                            .order(:recorded_at)
                            .limit(100)

    {
      data_type: 'daily',
      date_range: "#{start_date} to #{end_date}",
      records: daily_data.map { |record| format_health_data(record) }
    }
  end

  def get_sleep_data_for_user(connections, start_date, end_date)
    sleep_data = current_user.terra_health_data
                            .where(data_type: 'sleep', recorded_at: start_date..end_date)
                            .order(:recorded_at)
                            .limit(100)

    {
      data_type: 'sleep',
      date_range: "#{start_date} to #{end_date}",
      records: sleep_data.map { |record| format_health_data(record) }
    }
  end

  def get_body_data_for_user(connections, start_date, end_date)
    body_data = current_user.terra_health_data
                           .where(data_type: 'body', recorded_at: start_date..end_date)
                           .order(:recorded_at)
                           .limit(100)

    {
      data_type: 'body',
      date_range: "#{start_date} to #{end_date}",
      records: body_data.map { |record| format_health_data(record) }
    }
  end

  def get_all_data_for_user(connections, start_date, end_date)
    {
      summary: build_data_summary(connections, start_date, end_date),
      daily: get_daily_data_for_user(connections, start_date, end_date),
      sleep: get_sleep_data_for_user(connections, start_date, end_date),
      body: get_body_data_for_user(connections, start_date, end_date)
    }
  end

  def format_health_data(record)
    {
      id: record.id,
      data_type: record.data_type,
      provider: record.provider,
      recorded_at: record.recorded_at,
      value: record.value,
      unit: record.unit,
      raw_data: record.raw_data&.slice('summary') || record.raw_data, # Include summary for readability
      created_at: record.created_at
    }
  end
end 
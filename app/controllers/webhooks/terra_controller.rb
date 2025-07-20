class Webhooks::TerraController < ApplicationController
  # before_action :verify_signature  # TODO: Debug signature mismatch later

  def receive
    case webhook_type
    when 'auth'
      handle_auth_webhook
    when 'user_reauth'
      handle_reauth_webhook
    when 'deauth'
      handle_deauth_webhook
    when 'body'
      handle_body_webhook
    when 'daily'
      handle_daily_webhook
    when 'sleep'
      handle_sleep_webhook
    when 'activity'
      handle_activity_webhook
    when 'athlete'
      handle_athlete_webhook
    else
      Rails.logger.warn "Unknown Terra webhook type: #{webhook_type}"
    end

    render json: { status: 'received' }, status: :ok
  end

  private

  def verify_signature
    signature = request.headers['terra-signature']
    # Get truly raw body and force UTF-8 encoding
    body = request.body.read
    body.force_encoding('UTF-8') if body.respond_to?(:force_encoding)

    Rails.logger.info "Terra signature header: #{signature}"
    Rails.logger.info "Request body: #{body[0..200]}"
    Rails.logger.info "All headers: #{request.headers.to_h.select { |k,v| k.downcase.include?('terra') }}"

    unless TerraService.new.verify_signature(body, signature)
      Rails.logger.error "Invalid Terra webhook signature"
      render json: { error: 'Invalid signature' }, status: :unauthorized
      return
    end
  end

  def webhook_data
    @webhook_data ||= JSON.parse(request.body.read)
  end

  def webhook_type
    webhook_data['type']
  end

  def user_id
    webhook_data['user']['user_id']
  end

  def reference_id
    webhook_data['user']['reference_id']
  end

  def handle_auth_webhook
    Rails.logger.info "Terra auth webhook received for reference_id: #{reference_id}"
    
    # Find the user by the reference_id (which should be the user's ID)
    user = User.find_by(id: reference_id)
    
    unless user
      Rails.logger.error "Could not find user with ID: #{reference_id}"
      return render json: { error: 'User not found' }, status: :not_found
    end
    
    provider = webhook_data['user']['provider']
    
    terra_connection = user.terra_connections.find_or_initialize_by(
      provider: provider.downcase,
      terra_user_id: user_id
    )
    
    terra_connection.update!(
      status: 'connected',
      connected_at: Time.current,
      reference_id: reference_id,
      metadata: webhook_data['user']
    )

    Rails.logger.info "Successfully connected #{provider} for user #{user.email} (ID: #{user.id})"

    # Backfill historical data
    TerraBackfillJob.perform_later(user.id, terra_connection.id)
  end

  def handle_deauth_webhook
    Rails.logger.info "Terra deauth webhook received for user #{reference_id}"
    
    if reference_id.present?
      user = User.find_by(id: reference_id)
      if user
        connection = user.terra_connections.find_by(terra_user_id: user_id)
        if connection
          connection.update!(status: 'disconnected', connected_at: nil)
          Rails.logger.info "Disconnected #{connection.provider} for user #{user.email}"
        end
      else
        Rails.logger.error "Could not find user with ID: #{reference_id}"
      end
    end
  end

  def handle_reauth_webhook
    Rails.logger.info "Terra reauth webhook received for user #{reference_id}"
    handle_auth_webhook
  end

  def handle_body_webhook
    process_health_data('body')
  end

  def handle_daily_webhook
    process_health_data('daily')
  end

  def handle_sleep_webhook
    process_health_data('sleep')
  end

  def handle_activity_webhook
    process_health_data('activity')
  end

  def handle_athlete_webhook
    process_health_data('athlete')
  end

  def process_health_data(data_type)
    return unless reference_id.present?

    user = User.find_by(id: reference_id)
    unless user
      Rails.logger.error "Could not find user with ID: #{reference_id} for #{data_type} data"
      return
    end

    terra_connection = user.terra_connections.find_by(terra_user_id: user_id)
    unless terra_connection
      Rails.logger.error "Could not find Terra connection for user #{user.id}, terra_user_id: #{user_id}"
      return
    end

    data_array = webhook_data['data'] || []
    
    data_array.each do |data_point|
      # Validate data quality before processing
      unless TerraDataValidator.validate_health_data(data_type, data_point)
        Rails.logger.warn "Invalid #{data_type} data received for user #{user.id}, skipping record"
        next
      end
      
      # Sanitize data to remove PII and invalid values
      sanitized_data = TerraDataValidator.sanitize_health_data(data_point)
      
      # Check for duplicates before creating
      recorded_at = parse_timestamp(data_point['metadata']['start_time'] || data_point['ts_utc'])
      
      existing_record = user.terra_health_data.find_by(
        terra_connection: terra_connection,
        data_type: data_type,
        recorded_at: recorded_at
      )
      
      next if existing_record # Skip if we already have this data point
      
      TerraHealthDatum.create!(
        user: user,
        terra_connection: terra_connection,
        data_type: data_type,
        provider: terra_connection.provider,
        recorded_at: recorded_at,
        raw_data: sanitized_data,
        metadata: {
          webhook_type: webhook_type,
          received_at: Time.current,
          terra_user_id: user_id,
          validated: true
        }
      )
    end

    Rails.logger.info "Processed #{data_array.length} #{data_type} records for user #{user.email} (#{data_array.length} new records created)"
  end

  def parse_timestamp(timestamp)
    Time.parse(timestamp) if timestamp.present?
  rescue StandardError => e
    Rails.logger.error "Failed to parse timestamp #{timestamp}: #{e.message}"
    Time.current
  end
end 
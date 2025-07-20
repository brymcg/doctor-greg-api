class TerraService
  include HTTParty
  base_uri 'https://api.tryterra.co'

  def initialize
    @api_key = ENV['TERRA_API_KEY']
    @dev_id = ENV['TERRA_DEV_ID']
    @signing_secret = ENV['TERRA_SIGNING_SECRET']
  end

  # Generate widget session for user authentication
  def generate_widget_session(user_id, providers = nil)
    body = {
      language: "en",
      reference_id: user_id.to_s,
      auth_success_redirect_url: "#{ENV['FRONTEND_URL']}/integrations/success",
      auth_failure_redirect_url: "#{ENV['FRONTEND_URL']}/integrations/error"
    }
    
    # Add providers filter if specified
    body[:providers] = providers if providers
    
    response = self.class.post('/v2/auth/generateWidgetSession', {
      headers: headers,
      body: body.to_json
    })

    handle_response(response)
  end

  # Get user info from Terra
  def get_user_info(user_id)
    response = self.class.get("/user/info", {
      headers: headers,
      query: { user_id: user_id }
    })

    handle_response(response)
  end

  # Get historical data for a user (backfill)
  def get_body_data(user_id, start_date, end_date = Date.current)
    response = self.class.get("/body", {
      headers: headers,
      query: {
        user_id: user_id,
        start_date: start_date.strftime('%Y-%m-%d'),
        end_date: end_date.strftime('%Y-%m-%d')
      }
    })

    handle_response(response)
  end

  def get_daily_data(user_id, start_date, end_date = Date.current)
    response = self.class.get("/daily", {
      headers: headers,
      query: {
        user_id: user_id,
        start_date: start_date.strftime('%Y-%m-%d'),
        end_date: end_date.strftime('%Y-%m-%d')
      }
    })

    handle_response(response)
  end

  def get_sleep_data(user_id, start_date, end_date = Date.current)
    response = self.class.get("/sleep", {
      headers: headers,
      query: {
        user_id: user_id,
        start_date: start_date.strftime('%Y-%m-%d'),
        end_date: end_date.strftime('%Y-%m-%d')
      }
    })

    handle_response(response)
  end

  def get_activity_data(user_id, start_date, end_date = Date.current)
    response = self.class.get("/activity", {
      headers: headers,
      query: {
        user_id: user_id,
        start_date: start_date.strftime('%Y-%m-%d'),
        end_date: end_date.strftime('%Y-%m-%d')
      }
    })

    handle_response(response)
  end

  # Verify webhook signature according to Terra documentation
  def verify_signature(body, signature)
    return false unless signature

    # Step 1: Extract timestamp and signatures from header
    # Format: "t=timestamp,v1=signature,v0=old_signature"
    signature_parts = signature.split(',').map { |part| part.split('=', 2) }.to_h
    timestamp = signature_parts['t']
    received_signature = signature_parts['v1']  # Only use v1, ignore v0

    return false unless timestamp && received_signature

    # Step 2: Create signed payload: timestamp + "." + raw_body
    signed_payload = "#{timestamp}.#{body}"
    
    # Step 3: Calculate expected signature using HMAC-SHA256
    expected_signature = OpenSSL::HMAC.hexdigest('SHA256', @signing_secret, signed_payload)
    
    Rails.logger.info "Terra signature verification (official method):"
    Rails.logger.info "  Timestamp: #{timestamp}"
    Rails.logger.info "  Received signature: #{received_signature}"
    Rails.logger.info "  Signed payload: #{signed_payload[0..100]}..."
    Rails.logger.info "  Expected signature: #{expected_signature}"
    Rails.logger.info "  Body length: #{body.length}"
    Rails.logger.info "  Body encoding: #{body.encoding}"
    
    # Step 4: Compare signatures (constant-time comparison)
    match = ActiveSupport::SecurityUtils.secure_compare(expected_signature, received_signature)
    Rails.logger.info "  Signatures match: #{match}"
    match
  end

  # Deauthenticate user
  def deauthenticate_user(user_id)
    response = self.class.delete("/auth/deauthenticateUser", {
      headers: headers,
      body: { user_id: user_id }.to_json
    })

    handle_response(response)
  end

  private

  def headers
    {
      'Content-Type' => 'application/json',
      'dev-id' => @dev_id,
      'X-API-Key' => @api_key
    }
  end

  def handle_response(response)
    case response.code
    when 200..299
      response.parsed_response
    else
      Rails.logger.error "Terra API Error: #{response.code} - #{response.body}"
      { error: "Terra API Error: #{response.code}", details: response.parsed_response }
    end
  end
end 
class Api::V1::BaseController < ApplicationController
  before_action :set_session_id
  before_action :authenticate_user_or_session
  before_action :build_user_context

  protected

  def set_session_id
    @session_id = request.headers['X-Session-ID'] || SecureRandom.uuid
  end

  def authenticate_user_or_session
    # Try JWT authentication first
    token = AuthService.extract_token_from_header(request.headers['Authorization'])
    @current_user = AuthService.current_user_from_token(token) if token
    
    # If no JWT user, try to find user from session (for anonymous → registered user flow)
    @current_user ||= find_user_from_session
  end

  def build_user_context
    @user_context = {
      session_id: @session_id,
      user: @current_user,
      is_logged_in: @current_user.present?,
      onboarding_complete: onboarding_complete?,
      missing_onboarding_fields: missing_onboarding_fields,
      data_connections: user_data_connections,
      health_data_summary: user_health_data_summary,
      suggested_next_steps: suggested_next_steps
    }
  end

  def current_user
    @current_user
  end

  def user_context
    @user_context
  end

  def require_authentication!
    unless @current_user
      render json: { error: 'Authentication required' }, status: :unauthorized
    end
  end

  private

  def find_user_from_session
    # Check if any conversations for this session were associated with a user
    # This handles the case where anonymous user registers
    conversation_with_user = Conversation.for_session(@session_id).joins(:user).first
    conversation_with_user&.user
  end

  def onboarding_complete?
    return false unless @current_user
    UserService.user_onboarding_complete?(@current_user)
  end

  def missing_onboarding_fields
    return [] unless @current_user
    UserService.get_missing_onboarding_fields(@current_user)
  end

  def user_data_connections
    return [] unless @current_user
    # This would fetch Terra connections or other data sources
    @current_user.terra_connections.active rescue []
  end

  def user_health_data_summary
    return nil unless @current_user && user_data_connections.any?
    
    begin
      health_service = HealthDataService.new(@current_user)
      health_service.comprehensive_health_summary(days_back: 7) # Last week for context
    rescue => e
      Rails.logger.error "Failed to generate health data summary: #{e.message}"
      nil
    end
  end

  def suggested_next_steps
    UserService.get_suggested_next_steps(@current_user, user_data_connections)
  end
end 
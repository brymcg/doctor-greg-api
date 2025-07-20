class FunctionHandlerService
  class FunctionCallError < StandardError; end

  class << self
    def handle_function_results(function_results, user_context, session_id)
      results = []
      
      function_results.each do |result|
        case result[:function_name]
        when 'create_user'
          results << handle_create_user(result[:arguments], session_id)
        when 'update_user_profile'
          results << handle_update_user_profile(result[:arguments], user_context[:user])
        when 'create_terra_connection'
          results << handle_create_terra_connection(result[:arguments], user_context[:user])
        else
          Rails.logger.warn "Unknown function call: #{result[:function_name]}"
          results << { error: "Unknown function: #{result[:function_name]}" }
        end
      end
      
      results
    end

    private

    def handle_create_user(args, session_id)
      begin
        user = UserService.create_user_from_claude_args(args, session_id)
        token = AuthService.generate_token(user)
        {
          success: true,
          user_id: user.id,
          token: token,
          user: user,
          message: "User account created successfully"
        }
      rescue UserService::UserCreationError => e
        Rails.logger.error "Failed to create user via Claude function: #{e.message}"
        {
          success: false,
          error: e.message
        }
      end
    end

    def handle_update_user_profile(args, user)
      return { error: "No user found to update" } unless user
      
      begin
        updated_user = UserService.update_user_profile(user, args)
        {
          success: true,
          user_id: updated_user.id,
          message: "User profile updated successfully"
        }
      rescue UserService::UserUpdateError => e
        Rails.logger.error "Failed to update user via Claude function: #{e.message}"
        {
          success: false,
          error: e.message
        }
      end
    end

    def handle_create_terra_connection(args, user)
      provider = args['provider']&.upcase
      
      unless %w[APPLE_HEALTH WHOOP FITBIT GARMIN OURA POLAR].include?(provider)
        return {
          success: false,
          error: "Unsupported provider: #{provider}"
        }
      end

      begin
        return { success: false, error: "User not found" } unless user
        terra_service = TerraService.new
        
        # Generate auth URL for the user to connect their device
        result = terra_service.generate_auth_url(user.id, provider)
        
        if result['status'] == 'success'
          {
            success: true,
            auth_url: result['auth_url'],
            provider: provider.downcase,
            message: "I've generated a connection link for #{provider.downcase.humanize}. Click the link to connect your data:",
            instructions: "After clicking the link and completing authentication, your #{provider.downcase.humanize} data will be automatically synced to FLUX Health."
          }
        else
          {
            success: false,
            error: "Failed to generate connection link for #{provider}",
            details: result
          }
        end
      rescue StandardError => e
        Rails.logger.error "Failed to create Terra connection: #{e.message}"
        {
          success: false,
          error: "Connection setup failed",
          details: e.message
        }
      end
    end
  end
end 
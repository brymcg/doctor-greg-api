class ClaudeService
  include HTTParty
  base_uri 'https://api.anthropic.com'

  def initialize
    @api_key = ENV['CLAUDE_API_KEY']
    @headers = {
      'Content-Type' => 'application/json',
      'x-api-key' => @api_key,
      'anthropic-version' => '2023-06-01'
    }
  end

  def chat_with_context(message:, conversation:, user_context:)
    system_prompt = build_system_prompt(user_context)
    messages = build_conversation_messages(conversation, message)
    
    request_body = {
      model: 'claude-3-5-sonnet-20241022',
      max_tokens: 1000,
      system: system_prompt,
      messages: messages,
      tools: function_tools
    }

    begin
      response = self.class.post('/v1/messages', headers: @headers, body: request_body.to_json)
      
      if response.success?
        handle_claude_response(response.parsed_response)
      else
        {
          content: "I'm having trouble processing your request right now. Please try again in a moment.",
          function_results: nil
        }
      end
    rescue => e
      Rails.logger.error "Claude API error: #{e.message}"
      {
        content: "I'm experiencing technical difficulties. Please try again later.",
        function_results: nil
      }
    end
  end

  private

  def build_system_prompt(user_context)
    base_prompt = <<~PROMPT
      You are FLUX Health, an AI health assistant. You help users with personalized health insights, recommendations, and guidance.

      CURRENT USER CONTEXT:
      - Session ID: #{user_context[:session_id]}
      - Logged in: #{user_context[:is_logged_in]}
      - Onboarding complete: #{user_context[:onboarding_complete]}
    PROMPT

    if user_context[:user]
      base_prompt += <<~PROMPT
        - User: #{UserService.user_display_name(user_context[:user])}
        - Email: #{user_context[:user].email || 'Not provided'}
      PROMPT

      if user_context[:missing_onboarding_fields].any?
        base_prompt += <<~PROMPT
        - Missing profile info: #{user_context[:missing_onboarding_fields].join(', ')}
        PROMPT
      end

      if user_context[:data_connections].any?
        base_prompt += <<~PROMPT
        - Connected data sources: #{user_context[:data_connections].map(&:provider).join(', ')}
        PROMPT
        
        # Add health data summary if available
        if user_context[:health_data_summary]
          health_service = HealthDataService.new(user_context[:user])
          health_context = health_service.format_for_llm(days_back: 7)
          
          base_prompt += <<~PROMPT

        RECENT HEALTH DATA (Last 7 Days):
        #{health_context}
        PROMPT
        end
      else
        base_prompt += <<~PROMPT
        - No health data connections yet
        PROMPT
      end
    else
      base_prompt += <<~PROMPT
        - No user account yet
      PROMPT
    end

    base_prompt += <<~PROMPT

      CONVERSATION GUIDELINES:
      #{conversation_guidelines(user_context)}

      AVAILABLE FUNCTIONS:
      You can call these functions when appropriate:
      - create_user: Create a new user account when you have their basic info
      - update_user_profile: Update user profile information
      - create_terra_connection: Help connect health data sources

      Be conversational, helpful, and guide users naturally through their health journey.
    PROMPT

    base_prompt
  end

  def conversation_guidelines(user_context)
    if !user_context[:is_logged_in]
      <<~GUIDELINES
        - User is not logged in. Ask if they want to create an account or have an existing account.
        - To create an account, collect: name, email, secure password, date of birth, height, weight, activity level, biological sex
        - IMPORTANT: Always ask for a secure password (minimum 6 characters) before creating the account
        - Be natural - don't make it feel like a form. Collect information conversationally.
        - When you have all required info including password, call create_user function.
      GUIDELINES
    elsif !user_context[:onboarding_complete]
      <<~GUIDELINES
        - User is logged in but missing profile information: #{user_context[:missing_onboarding_fields].join(', ')}
        - Help them complete their profile by asking for missing information naturally.
        - Use update_user_profile function when they provide information.
      GUIDELINES
    elsif user_context[:data_connections].empty?
      <<~GUIDELINES
        - User has complete profile but no health data connections.
        - Suggest connecting Apple Health, Whoop, or other health devices for better insights.
        - Explain benefits of data connections for personalized recommendations.
        - Also answer any health questions they might have.
      GUIDELINES
    else
      <<~GUIDELINES
        - User is fully set up with health data connections.
        - Provide personalized health insights, answer questions, give recommendations.
        - Use their connected data context when relevant.
      GUIDELINES
    end
  end

  def build_conversation_messages(conversation, current_message)
    ConversationService.build_message_history(conversation, current_message, 10)
  end

  def function_tools
    [
      {
        name: 'create_user',
        description: 'Create a new user account when you have collected sufficient information',
        input_schema: {
          type: 'object',
          properties: {
            name: { type: 'string', description: 'Full name' },
            email: { type: 'string', description: 'Email address' },
            password: { type: 'string', description: 'Secure password for account login (minimum 6 characters)' },
            date_of_birth: { type: 'string', description: 'Date of birth in YYYY-MM-DD format' },
            height: { type: 'string', description: 'Height with units (e.g., "5\'8\"" or "173cm")' },
            weight: { type: 'string', description: 'Weight with units (e.g., "150lbs" or "68kg")' },
            activity_level: { 
              type: 'string', 
              enum: ['sedentary', 'lightly_active', 'moderately_active', 'very_active', 'extremely_active'],
              description: 'Activity level'
            },
            biological_sex: { 
              type: 'string', 
              enum: ['male', 'female', 'other'],
              description: 'Biological sex (for health calculations and recommendations)'
            },
            health_goals: { 
              type: 'array', 
              items: { type: 'string' },
              description: 'List of health goals'
            },
            health_conditions: { 
              type: 'array', 
              items: { type: 'string' },
              description: 'List of health conditions or concerns'
            }
          },
          required: ['name', 'email', 'password']
        }
      },
      {
        name: 'update_user_profile',
        description: 'Update user profile information',
        input_schema: {
          type: 'object',
          properties: {
            name: { type: 'string', description: 'Full name' },
            date_of_birth: { type: 'string', description: 'Date of birth in YYYY-MM-DD format' },
            height: { type: 'string', description: 'Height with units' },
            weight: { type: 'string', description: 'Weight with units' },
            activity_level: { 
              type: 'string', 
              enum: ['sedentary', 'lightly_active', 'moderately_active', 'very_active', 'extremely_active']
            },
            health_goals: { type: 'array', items: { type: 'string' } },
            health_conditions: { type: 'array', items: { type: 'string' } }
          }
        }
      },
      {
        name: 'create_terra_connection',
        description: 'Help user connect health data sources like Apple Health, Whoop, etc.',
        input_schema: {
          type: 'object',
          properties: {
            provider: { 
              type: 'string',
              enum: ['apple_health', 'whoop', 'fitbit', 'garmin'],
              description: 'Health data provider to connect'
            }
          },
          required: ['provider']
        }
      }
    ]
  end

  def handle_claude_response(response)
    content = ''
    function_results = []

    response['content'].each do |content_block|
      case content_block['type']
      when 'text'
        content += content_block['text']
      when 'tool_use'
        function_results << {
          function_name: content_block['name'],
          arguments: content_block['input']
        }
      end
    end

    {
      content: content.present? ? content : "I understand. Let me help you with that.",
      function_results: function_results.any? ? function_results : nil
    }
  end
end 
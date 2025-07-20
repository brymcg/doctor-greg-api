require 'ostruct'

class Api::V1::ChatController < Api::V1::BaseController
  def send_message
    user_message = params[:message]
    conversation_id = params[:conversation_id]
    
    # Get or create conversation using service
    conversation = ConversationService.get_or_create_conversation(
      conversation_id, 
      current_user, 
      @session_id
    )
    
    # Create user message
    user_msg = ConversationService.create_message(conversation, 'user', user_message)
    
    # Get Claude response with user context
    claude_response = ClaudeService.new.chat_with_context(
      message: user_message,
      conversation: conversation,
      user_context: user_context
    )
    
    # Create assistant message
    assistant_msg = ConversationService.create_message(
      conversation, 
      'assistant', 
      claude_response[:content]
    )
    
    # Update conversation timestamp
    ConversationService.update_conversation_timestamp(conversation)
    
    # Handle any function calls Claude made
    if claude_response[:function_results]
      function_results = FunctionHandlerService.handle_function_results(
        claude_response[:function_results], 
        user_context, 
        @session_id
      )
      
      # Rebuild user context after potential user creation/updates
      build_user_context
    end
    
    render json: {
      message: format_message_response(assistant_msg),
      conversation: ConversationService.format_conversation_response(conversation),
      user_context: user_context,
      function_results: function_results || []
    }
  end

  def conversations
    conversations = ConversationService.list_conversations(current_user, @session_id)
    render json: ConversationService.format_conversation_list(conversations)
  end

  def new_conversation
    conversation = ConversationService.get_or_create_conversation(nil, current_user, @session_id)
    render json: ConversationService.format_conversation_response(conversation)
  end

  private

  def format_message_response(message)
    {
      id: message.id,
      content: message.content,
      role: message.role,
      created_at: message.created_at
    }
  end
end 
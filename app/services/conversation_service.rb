class ConversationService
  class ConversationNotFound < StandardError; end

  class << self
    def get_or_create_conversation(conversation_id, user, session_id)
      # Try to find existing conversation
      if conversation_id
        conversation = find_conversation(conversation_id, user, session_id)
        return conversation if conversation
      end
      
      # Create new conversation
      create_new_conversation(user, session_id)
    end

    def list_conversations(user, session_id)
      if user
        user.conversations.recent.includes(:messages)
      else
        Conversation.for_session(session_id).recent.includes(:messages)
      end
    end

    def create_message(conversation, role, content)
      conversation.messages.create!(
        role: role,
        content: content
      )
    end

    def update_conversation_timestamp(conversation)
      conversation.touch
    end

    def format_conversation_list(conversations)
      conversations.map do |conv|
        {
          id: conv.id,
          title: conv.title,
          updated_at: conv.updated_at,
          message_count: conv.message_count,
          latest_message: conv.latest_message&.content&.truncate(100)
        }
      end
    end

    def format_conversation_response(conversation)
      {
        id: conversation.id,
        title: conversation.title,
        created_at: conversation.created_at,
        updated_at: conversation.updated_at
      }
    end

    def build_message_history(conversation, current_message, limit = 10)
      messages = []
      
      # Add conversation history (last N messages to keep context manageable)
      # Exclude the current message since it hasn't been saved yet
      recent_messages = conversation.messages.order(:created_at).last(limit)
      recent_messages.each do |msg|
        next if msg.content == current_message # Skip the current message we're processing
        messages << {
          role: msg.role,
          content: msg.content
        }
      end
      
      # Add current message
      messages << {
        role: 'user',
        content: current_message
      }
      
      messages
    end

    def generate_conversation_title(first_message)
      # Generate a title from the first message (first 50 chars)
      return "New conversation" unless first_message
      
      title = first_message.length > 50 ? "#{first_message[0..47]}..." : first_message
      title.presence || "New conversation"
    end

    private

    def find_conversation(conversation_id, user, session_id)
      if user
        user.conversations.find_by(id: conversation_id)
      else
        Conversation.for_session(session_id).find_by(id: conversation_id)
      end
    end

    def create_new_conversation(user, session_id)
      if user
        user.conversations.create!(
          title: "New conversation"
        )
      else
        Conversation.create!(
          session_id: session_id,
          title: "New conversation"
        )
      end
    end
  end
end 
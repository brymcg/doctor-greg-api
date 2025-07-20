class Message < ApplicationRecord
  belongs_to :conversation

  validates :role, presence: true
  validates :content, presence: true, length: { minimum: 1, maximum: 10000 }

  enum role: {
    user: 'user',
    assistant: 'assistant',
    system: 'system'
  }

  scope :recent, -> { order(created_at: :desc) }
  scope :conversation_order, -> { order(created_at: :asc) }

  def user_message?
    role == 'user'
  end

  def assistant_message?
    role == 'assistant'
  end

  def word_count
    content.split.length
  end

  def truncated_content(limit = 100)
    return content if content.length <= limit
    "#{content[0..limit-4]}..."
  end
end

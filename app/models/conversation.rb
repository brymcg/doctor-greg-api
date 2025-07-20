class Conversation < ApplicationRecord
  belongs_to :user, optional: true
  has_many :messages, dependent: :destroy

  validates :title, presence: true
  validates :session_id, presence: true, if: -> { user_id.blank? }
  validates :user_id, presence: true, if: -> { session_id.blank? }

  scope :for_session, ->(session_id) { where(session_id: session_id) }
  scope :for_user, ->(user) { where(user: user) }
  scope :recent, -> { order(updated_at: :desc) }

  def anonymous?
    user_id.blank?
  end

  def latest_message
    messages.order(:created_at).last
  end

  def message_count
    messages.count
  end
end

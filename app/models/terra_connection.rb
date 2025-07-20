class TerraConnection < ApplicationRecord
  belongs_to :user
  has_many :terra_health_data, dependent: :destroy

  validates :provider, presence: true
  validates :terra_user_id, presence: true, uniqueness: { scope: :user_id }
  validates :status, presence: true

  enum status: {
    pending: 'pending',
    connected: 'connected',
    disconnected: 'disconnected',
    error: 'error'
  }

  enum provider: {
    apple_health: 'apple_health',
    whoop: 'whoop',
    fitbit: 'fitbit',
    garmin: 'garmin',
    oura: 'oura',
    polar: 'polar'
  }

  scope :active, -> { where(status: :connected) }

  def connected?
    status == 'connected'
  end

  def disconnect!
    update!(status: :disconnected, connected_at: nil)
  end

  def mark_connected!
    update!(status: :connected, connected_at: Time.current)
  end
end

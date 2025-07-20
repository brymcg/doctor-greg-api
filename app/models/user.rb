class User < ApplicationRecord
  has_secure_password

  validates :email, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 6 }, if: -> { new_record? || !password.nil? }

  # Health attribute validations
  validates :height_cm, numericality: { greater_than: 0, less_than: 300 }, allow_nil: true
  validates :weight_kg, numericality: { greater_than: 0, less_than: 1000 }, allow_nil: true
  validates :date_of_birth, presence: true, if: :onboarded?
  validates :biological_sex, inclusion: { in: %w[male female other] }, allow_nil: true
  validates :activity_level, inclusion: { in: %w[sedentary lightly_active moderately_active very_active] }, allow_nil: true
  validates :units_preference, inclusion: { in: %w[metric imperial] }, allow_nil: true

  # Enums for better type safety
  enum activity_level: {
    sedentary: 'sedentary',
    lightly_active: 'lightly_active',
    moderately_active: 'moderately_active',
    very_active: 'very_active'
  }

  enum biological_sex: {
    male: 'male',
    female: 'female',
    other: 'other'
  }

  enum units_preference: {
    metric: 'metric',
    imperial: 'imperial'
  }

  # Terra integration associations
  has_many :terra_connections, dependent: :destroy
  has_many :terra_health_data, dependent: :destroy

  # Chat associations
  has_many :conversations, dependent: :destroy
  has_many :messages, through: :conversations

  # Health data associations (will add these as we create the models)
  # has_many :apple_health_records, dependent: :destroy
  # has_many :whoop_records, dependent: :destroy
  # has_many :blood_test_records, dependent: :destroy
  # has_many :body_metrics, dependent: :destroy
  # has_many :sleep_records, dependent: :destroy
  # has_many :step_records, dependent: :destroy
  # has_many :recovery_records, dependent: :destroy

  def onboarded?
    onboarded_at.present?
  end

  def age
    return nil unless date_of_birth
    ((Time.current - date_of_birth.to_time) / 1.year.seconds).floor
  end

  def height_in_preferred_units
    return nil unless height_cm
    units_preference == 'imperial' ? (height_cm / 2.54).round(1) : height_cm
  end

  def weight_in_preferred_units
    return nil unless weight_kg
    units_preference == 'imperial' ? (weight_kg * 2.20462).round(1) : weight_kg
  end

  # Terra integration helpers
  def connected_providers
    terra_connections.active.pluck(:provider)
  end

  def has_terra_connection?(provider)
    terra_connections.where(provider: provider, status: 'connected').exists?
  end

  def latest_health_data(data_type)
    terra_health_data.by_type(data_type).recent.first
  end

  # Chat helpers
  def recent_conversations(limit = 10)
    conversations.recent.limit(limit)
  end

  def create_conversation(first_message)
    conversation = Conversation.create_with_title(self, first_message)
    conversation.add_message('user', first_message)
    conversation
  end
end 
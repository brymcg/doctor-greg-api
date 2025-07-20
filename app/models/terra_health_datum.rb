class TerraHealthDatum < ApplicationRecord
  belongs_to :user
  belongs_to :terra_connection

  validates :data_type, presence: true
  validates :provider, presence: true
  validates :recorded_at, presence: true

  enum provider: {
    apple_health: 'apple_health',
    whoop: 'whoop',
    fitbit: 'fitbit',
    garmin: 'garmin',
    oura: 'oura',
    polar: 'polar'
  }

  enum data_type: {
    steps: 'steps',
    heart_rate: 'heart_rate',
    heart_rate_variability: 'heart_rate_variability',
    sleep: 'sleep',
    activity: 'activity',
    workout: 'workout',
    body_weight: 'body_weight',
    body_fat: 'body_fat',
    blood_pressure: 'blood_pressure',
    blood_glucose: 'blood_glucose',
    active_energy: 'active_energy',
    distance: 'distance',
    floors_climbed: 'floors_climbed',
    vo2_max: 'vo2_max',
    respiratory_rate: 'respiratory_rate'
  }

  scope :recent, -> { order(recorded_at: :desc) }
  scope :by_type, ->(type) { where(data_type: type) }
  scope :today, -> { where(recorded_at: Time.current.beginning_of_day..Time.current.end_of_day) }
  scope :this_week, -> { where(recorded_at: 1.week.ago..Time.current) }

  def self.latest_by_type(type)
    by_type(type).recent.first
  end
end

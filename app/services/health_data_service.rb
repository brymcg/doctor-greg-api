class HealthDataService
  def initialize(user)
    @user = user
  end

  # Get comprehensive health summary for LLM context
  def comprehensive_health_summary(days_back: 30)
    end_date = Date.current
    start_date = end_date - days_back.days

    {
      user_profile: user_profile_summary,
      activity_summary: activity_summary(start_date, end_date),
      sleep_summary: sleep_summary(start_date, end_date),
      heart_rate_summary: heart_rate_summary(start_date, end_date),
      body_metrics_summary: body_metrics_summary(start_date, end_date),
      recent_trends: analyze_trends(start_date, end_date),
      data_quality: assess_data_quality(start_date, end_date),
      connected_providers: @user.connected_providers,
      analysis_period: "#{start_date} to #{end_date}"
    }
  end

  # Format health data for Claude in readable format
  def format_for_llm(days_back: 7)
    summary = comprehensive_health_summary(days_back: days_back)
    
    context = []
    context << "## User Health Profile"
    context << format_user_profile(summary[:user_profile])
    
    context << "\n## Recent Activity Summary (#{days_back} days)"
    context << format_activity_summary(summary[:activity_summary])
    
    context << "\n## Sleep Patterns"
    context << format_sleep_summary(summary[:sleep_summary])
    
    context << "\n## Heart Rate & Recovery"
    context << format_heart_rate_summary(summary[:heart_rate_summary])
    
    context << "\n## Body Metrics"
    context << format_body_metrics(summary[:body_metrics_summary])
    
    context << "\n## Health Trends"
    context << format_trends(summary[:recent_trends])
    
    context << "\n## Data Sources"
    context << "Connected providers: #{summary[:connected_providers].join(', ')}"
    context << "Data quality: #{summary[:data_quality][:overall_score]}% (#{summary[:data_quality][:total_records]} records)"
    
    context.join("\n")
  end

  # Get specific data for focused analysis
  def activity_data_for_analysis(activity_type: nil, days_back: 7)
    data = @user.terra_health_data
               .where(data_type: 'activity')
               .where(recorded_at: days_back.days.ago..Time.current)
               .order(:recorded_at)

    data.map do |record|
      activity = extract_activity_metrics(record.raw_data)
      next unless activity_type.nil? || activity[:type] == activity_type
      
      {
        date: record.recorded_at.to_date,
        provider: record.provider,
        activity: activity
      }
    end.compact
  end

  private

  def user_profile_summary
    {
      age: @user.age,
      biological_sex: @user.biological_sex,
      height: @user.height_in_preferred_units,
      weight: @user.weight_in_preferred_units,
      activity_level: @user.activity_level,
      units: @user.units_preference || 'metric'
    }
  end

  def activity_summary(start_date, end_date)
    activity_data = @user.terra_health_data
                        .where(data_type: 'activity', recorded_at: start_date..end_date)
                        .order(:recorded_at)

    total_activities = activity_data.count
    return { total_activities: 0 } if total_activities == 0

    activities_by_type = {}
    total_calories = 0
    total_distance = 0
    total_duration = 0

    activity_data.each do |record|
      activity = extract_activity_metrics(record.raw_data)
      
      type = activity[:type] || 'unknown'
      activities_by_type[type] ||= { count: 0, total_calories: 0, total_distance: 0, total_duration: 0 }
      activities_by_type[type][:count] += 1
      activities_by_type[type][:total_calories] += activity[:calories] || 0
      activities_by_type[type][:total_distance] += activity[:distance_km] || 0
      activities_by_type[type][:total_duration] += activity[:duration_minutes] || 0
      
      total_calories += activity[:calories] || 0
      total_distance += activity[:distance_km] || 0
      total_duration += activity[:duration_minutes] || 0
    end

    {
      total_activities: total_activities,
      activities_by_type: activities_by_type,
      totals: {
        calories: total_calories.round,
        distance_km: total_distance.round(1),
        duration_hours: (total_duration / 60.0).round(1)
      },
      avg_per_activity: {
        calories: (total_calories / total_activities).round,
        distance_km: (total_distance / total_activities).round(1),
        duration_minutes: (total_duration / total_activities).round
      }
    }
  end

  def sleep_summary(start_date, end_date)
    sleep_data = @user.terra_health_data
                     .where(data_type: 'sleep', recorded_at: start_date..end_date)
                     .order(:recorded_at)

    return { nights_recorded: 0 } if sleep_data.empty?

    total_sleep_minutes = 0
    total_deep_sleep_minutes = 0
    total_rem_sleep_minutes = 0
    sleep_scores = []

    sleep_data.each do |record|
      sleep = extract_sleep_metrics(record.raw_data)
      total_sleep_minutes += sleep[:total_sleep_minutes] || 0
      total_deep_sleep_minutes += sleep[:deep_sleep_minutes] || 0
      total_rem_sleep_minutes += sleep[:rem_sleep_minutes] || 0
      sleep_scores << sleep[:sleep_score] if sleep[:sleep_score]
    end

    nights = sleep_data.count
    {
      nights_recorded: nights,
      avg_sleep_hours: (total_sleep_minutes / nights / 60.0).round(1),
      avg_deep_sleep_minutes: (total_deep_sleep_minutes / nights).round,
      avg_rem_sleep_minutes: (total_rem_sleep_minutes / nights).round,
      avg_sleep_score: sleep_scores.any? ? (sleep_scores.sum.to_f / sleep_scores.length).round : nil
    }
  end

  def heart_rate_summary(start_date, end_date)
    # Get heart rate data from activity records (since that's what we're receiving)
    activity_data = @user.terra_health_data
                        .where(data_type: 'activity', recorded_at: start_date..end_date)

    heart_rates = []
    resting_hrs = []

    activity_data.each do |record|
      hr_data = extract_heart_rate_from_activity(record.raw_data)
      heart_rates.concat(hr_data[:hr_samples]) if hr_data[:hr_samples]
      resting_hrs << hr_data[:resting_hr] if hr_data[:resting_hr]
    end

    return { data_available: false } if heart_rates.empty?

    {
      data_available: true,
      avg_exercise_hr: (heart_rates.sum / heart_rates.length).round,
      max_hr: heart_rates.max,
      min_hr: heart_rates.min,
      avg_resting_hr: resting_hrs.any? ? (resting_hrs.sum / resting_hrs.length).round : nil,
      total_hr_samples: heart_rates.length
    }
  end

  def body_metrics_summary(start_date, end_date)
    body_data = @user.terra_health_data
                    .where(data_type: 'body', recorded_at: start_date..end_date)
                    .order(:recorded_at)

    return { measurements: 0 } if body_data.empty?

    weights = []
    body_fat_percentages = []

    body_data.each do |record|
      metrics = extract_body_metrics(record.raw_data)
      weights << metrics[:weight_kg] if metrics[:weight_kg]
      body_fat_percentages << metrics[:body_fat_percentage] if metrics[:body_fat_percentage]
    end

    {
      measurements: body_data.count,
      latest_weight_kg: weights.last,
      avg_weight_kg: weights.any? ? (weights.sum / weights.length).round(1) : nil,
      weight_trend: weights.length > 1 ? calculate_trend(weights) : 'insufficient_data',
      avg_body_fat_percentage: body_fat_percentages.any? ? (body_fat_percentages.sum / body_fat_percentages.length).round(1) : nil
    }
  end

  def analyze_trends(start_date, end_date)
    # Basic trend analysis
    {
      activity_trend: analyze_activity_trend(start_date, end_date),
      sleep_trend: analyze_sleep_trend(start_date, end_date),
      consistency_score: calculate_consistency_score(start_date, end_date)
    }
  end

  def assess_data_quality(start_date, end_date)
    total_records = @user.terra_health_data.where(recorded_at: start_date..end_date).count
    expected_days = (Date.current - start_date).to_i + 1
    
    activity_days = @user.terra_health_data.where(data_type: 'activity', recorded_at: start_date..end_date).count
    sleep_days = @user.terra_health_data.where(data_type: 'sleep', recorded_at: start_date..end_date).count
    
    coverage_score = [(activity_days.to_f / expected_days * 100).round, 100].min

    {
      total_records: total_records,
      expected_days: expected_days,
      activity_coverage: "#{activity_days}/#{expected_days} days",
      sleep_coverage: "#{sleep_days}/#{expected_days} days",
      overall_score: coverage_score
    }
  end

  # Data extraction helpers
  def extract_activity_metrics(raw_data)
    return {} unless raw_data.is_a?(Hash)

    metadata = raw_data['metadata'] || {}
    calories = raw_data['calories_data'] || {}
    distance = raw_data['distance_data'] || {}
    movement = raw_data['movement_data'] || {}

    {
      type: metadata['name'] || metadata['type'],
      start_time: metadata['start_time'],
      end_time: metadata['end_time'],
      duration_minutes: calculate_duration_minutes(metadata['start_time'], metadata['end_time']),
      calories: calories['total_burned_calories']&.round,
      distance_km: distance.dig('summary', 'distance_meters')&.then { |m| (m / 1000.0).round(2) },
      steps: distance.dig('summary', 'steps'),
      avg_heart_rate: raw_data.dig('heart_rate_data', 'summary', 'avg_hr_bpm'),
      max_heart_rate: raw_data.dig('heart_rate_data', 'summary', 'max_hr_bpm'),
      avg_speed_kmh: movement['avg_speed_meters_per_second']&.then { |ms| (ms * 3.6).round(1) }
    }
  end

  def extract_sleep_metrics(raw_data)
    return {} unless raw_data.is_a?(Hash)
    # Add sleep data extraction when we receive sleep webhooks
    {}
  end

  def extract_heart_rate_from_activity(raw_data)
    hr_data = raw_data.dig('heart_rate_data', 'summary') || {}
    hr_samples = raw_data.dig('heart_rate_data', 'detailed', 'hr_samples') || []
    
    {
      hr_samples: hr_samples.map { |sample| sample['bpm'] }.compact,
      resting_hr: hr_data['resting_hr_bpm'],
      avg_hr: hr_data['avg_hr_bpm'],
      max_hr: hr_data['max_hr_bpm']
    }
  end

  def extract_body_metrics(raw_data)
    return {} unless raw_data.is_a?(Hash)
    # Add body metrics extraction when we receive body webhooks
    {}
  end

  # Formatting helpers for LLM
  def format_user_profile(profile)
    parts = []
    parts << "Age: #{profile[:age]}" if profile[:age]
    parts << "Sex: #{profile[:biological_sex]}" if profile[:biological_sex]
    parts << "Height: #{profile[:height]} #{profile[:units] == 'imperial' ? 'inches' : 'cm'}" if profile[:height]
    parts << "Weight: #{profile[:weight]} #{profile[:units] == 'imperial' ? 'lbs' : 'kg'}" if profile[:weight]
    parts << "Activity Level: #{profile[:activity_level]&.humanize}" if profile[:activity_level]
    parts.join(", ")
  end

  def format_activity_summary(summary)
    return "No activity data available" if summary[:total_activities] == 0

    lines = []
    lines << "Total activities: #{summary[:total_activities]}"
    lines << "Total calories burned: #{summary[:totals][:calories]}"
    lines << "Total distance: #{summary[:totals][:distance_km]} km"
    lines << "Total exercise time: #{summary[:totals][:duration_hours]} hours"
    
    if summary[:activities_by_type].any?
      lines << "\nActivity breakdown:"
      summary[:activities_by_type].each do |type, data|
        lines << "- #{type.humanize}: #{data[:count]} sessions"
      end
    end
    
    lines.join("\n")
  end

  def format_sleep_summary(summary)
    return "No sleep data available" if summary[:nights_recorded] == 0

    lines = []
    lines << "Nights recorded: #{summary[:nights_recorded]}"
    lines << "Average sleep: #{summary[:avg_sleep_hours]} hours"
    lines << "Average deep sleep: #{summary[:avg_deep_sleep_minutes]} minutes" if summary[:avg_deep_sleep_minutes]
    lines << "Average REM sleep: #{summary[:avg_rem_sleep_minutes]} minutes" if summary[:avg_rem_sleep_minutes]
    lines << "Average sleep score: #{summary[:avg_sleep_score]}" if summary[:avg_sleep_score]
    lines.join("\n")
  end

  def format_heart_rate_summary(summary)
    return "No heart rate data available" unless summary[:data_available]

    lines = []
    lines << "Average exercise heart rate: #{summary[:avg_exercise_hr]} bpm"
    lines << "Max heart rate: #{summary[:max_hr]} bpm"
    lines << "Resting heart rate: #{summary[:avg_resting_hr]} bpm" if summary[:avg_resting_hr]
    lines << "Heart rate samples: #{summary[:total_hr_samples]}"
    lines.join("\n")
  end

  def format_body_metrics(summary)
    return "No body metrics available" if summary[:measurements] == 0

    lines = []
    lines << "Weight measurements: #{summary[:measurements]}"
    lines << "Latest weight: #{summary[:latest_weight_kg]} kg" if summary[:latest_weight_kg]
    lines << "Average weight: #{summary[:avg_weight_kg]} kg" if summary[:avg_weight_kg]
    lines << "Weight trend: #{summary[:weight_trend]}" if summary[:weight_trend] != 'insufficient_data'
    lines << "Body fat: #{summary[:avg_body_fat_percentage]}%" if summary[:avg_body_fat_percentage]
    lines.join("\n")
  end

  def format_trends(trends)
    lines = []
    lines << "Activity trend: #{trends[:activity_trend]}" if trends[:activity_trend]
    lines << "Sleep trend: #{trends[:sleep_trend]}" if trends[:sleep_trend]
    lines << "Consistency score: #{trends[:consistency_score]}%" if trends[:consistency_score]
    lines.join("\n")
  end

  # Helper methods
  def calculate_duration_minutes(start_time, end_time)
    return nil unless start_time && end_time
    
    start_dt = Time.parse(start_time)
    end_dt = Time.parse(end_time)
    ((end_dt - start_dt) / 60).round
  rescue
    nil
  end

  def calculate_trend(values)
    return 'insufficient_data' if values.length < 2
    
    recent_avg = values.last(3).sum / values.last(3).length
    earlier_avg = values.first(3).sum / values.first(3).length
    
    diff_percentage = ((recent_avg - earlier_avg) / earlier_avg * 100).round(1)
    
    case diff_percentage
    when -Float::INFINITY..-5 then 'decreasing'
    when -5..5 then 'stable'
    when 5..Float::INFINITY then 'increasing'
    else 'stable'
    end
  end

  def analyze_activity_trend(start_date, end_date)
    # Placeholder for more sophisticated trend analysis
    'stable'
  end

  def analyze_sleep_trend(start_date, end_date)
    # Placeholder for sleep trend analysis
    'stable'
  end

  def calculate_consistency_score(start_date, end_date)
    # Placeholder for consistency scoring
    75
  end
end 
class TerraDataValidator
  def self.validate_health_data(data_type, raw_data)
    return false unless raw_data.is_a?(Hash)
    
    case data_type
    when 'activity'
      validate_activity_data(raw_data)
    when 'sleep'
      validate_sleep_data(raw_data)
    when 'body'
      validate_body_data(raw_data)
    when 'daily'
      validate_daily_data(raw_data)
    else
      true # Allow unknown types for forward compatibility
    end
  end

  def self.sanitize_health_data(raw_data)
    return {} unless raw_data.is_a?(Hash)
    
    # Remove any potentially sensitive or unnecessary data
    sanitized = raw_data.deep_dup
    
    # Remove any PII that shouldn't be stored
    sanitized.delete('user_email') if sanitized['user_email']
    sanitized.delete('user_name') if sanitized['user_name']
    
    # Ensure numeric values are within reasonable ranges
    sanitize_numeric_values(sanitized)
    
    sanitized
  end

  private

  def self.validate_activity_data(data)
    metadata = data['metadata'] || {}
    
    # Basic validation
    return false unless metadata['start_time'].present?
    return false unless valid_timestamp?(metadata['start_time'])
    
    # Validate calories if present
    if calories = data.dig('calories_data', 'total_burned_calories')
      return false unless calories.is_a?(Numeric) && calories >= 0 && calories < 10000
    end
    
    # Validate heart rate if present
    if avg_hr = data.dig('heart_rate_data', 'summary', 'avg_hr_bpm')
      return false unless avg_hr.is_a?(Numeric) && avg_hr > 0 && avg_hr < 300
    end
    
    true
  end

  def self.validate_sleep_data(data)
    # Add sleep data validation when we receive sleep webhooks
    return true unless data['sleep_duration_seconds']
    
    duration = data['sleep_duration_seconds']
    duration.is_a?(Numeric) && duration > 0 && duration < 86400 # Max 24 hours
  end

  def self.validate_body_data(data)
    # Validate weight if present
    if weight = data['weight_kg']
      return false unless weight.is_a?(Numeric) && weight > 0 && weight < 1000
    end
    
    # Validate body fat percentage if present
    if body_fat = data['body_fat_percentage']
      return false unless body_fat.is_a?(Numeric) && body_fat >= 0 && body_fat <= 100
    end
    
    true
  end

  def self.validate_daily_data(data)
    # Validate steps if present
    if steps = data['steps']
      return false unless steps.is_a?(Numeric) && steps >= 0 && steps < 100000
    end
    
    # Validate distance if present
    if distance = data['distance_meters']
      return false unless distance.is_a?(Numeric) && distance >= 0 && distance < 1000000 # Max 1000km
    end
    
    true
  end

  def self.valid_timestamp?(timestamp_str)
    Time.parse(timestamp_str)
    true
  rescue
    false
  end

  def self.sanitize_numeric_values(data)
    data.each do |key, value|
      case value
      when Hash
        sanitize_numeric_values(value)
      when Array
        value.each { |item| sanitize_numeric_values(item) if item.is_a?(Hash) }
      when Float
        # Handle infinity and NaN values
        data[key] = nil if value.infinite? || value.nan?
      end
    end
  end
end 
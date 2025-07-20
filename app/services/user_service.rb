class UserService
  class UserCreationError < StandardError; end
  class UserUpdateError < StandardError; end

  class << self
    def create_user_from_claude_args(args, session_id = nil)
      mapped_args = map_user_attributes(args)
      
      # Use provided password or generate temporary one
      if args['password'].present?
        mapped_args[:password] = args['password']
      else
        mapped_args[:password] = generate_temp_password
        Rails.logger.warn "Generated temporary password for user #{args['email']}"
      end
      
      user = User.new(mapped_args)
      
      if user.save
        # Associate any existing anonymous conversations with the new user
        if session_id
          associate_anonymous_conversations(user, session_id)
        end
        
        user
      else
        raise UserCreationError, user.errors.full_messages.join(', ')
      end
    end

    def update_user_profile(user, args)
      mapped_args = map_user_attributes(args.except('id'))
      
      if user.update(mapped_args)
        user
      else
        raise UserUpdateError, user.errors.full_messages.join(', ')
      end
    end

    def user_onboarding_complete?(user)
      required_fields = %w[first_name email date_of_birth height_cm weight_kg activity_level biological_sex]
      required_fields.all? { |field| user.send(field).present? }
    end

    def get_missing_onboarding_fields(user)
      required_fields = {
        'first_name' => 'First name',
        'email' => 'Email address', 
        'date_of_birth' => 'Date of birth',
        'height_cm' => 'Height',
        'weight_kg' => 'Weight',
        'activity_level' => 'Activity level',
        'biological_sex' => 'Biological sex'
      }
      
      required_fields.select { |field, _| user.send(field).blank? }.values
    end

    def get_suggested_next_steps(user, data_connections = [])
      steps = []
      
      unless user
        steps << "Create account or log in"
        return steps
      end
      
      unless user_onboarding_complete?(user)
        steps << "Complete profile setup"
        return steps
      end
      
      if data_connections.empty?
        steps << "Connect health data (Apple Health, Whoop, etc.)"
      end
      
      steps << "Ask health questions or explore insights"
      steps
    end

    def user_display_name(user)
      return 'Unknown' unless user
      [user.first_name, user.last_name].compact.join(' ').presence || 'Unknown'
    end

    private

    def generate_temp_password
      SecureRandom.alphanumeric(12)
    end

    def associate_anonymous_conversations(user, session_id)
      # Keep the session_id so we can find the user later
      Conversation.for_session(session_id).update_all(user_id: user.id)
    end

    def map_user_attributes(args)
      mapped = {}
      
      # Handle name mapping
      if args['name']
        name_parts = args['name'].split(' ', 2)
        mapped[:first_name] = name_parts[0]
        mapped[:last_name] = name_parts[1] || ''
      end
      
      # Map other attributes
      mapped[:first_name] = args['first_name'] if args['first_name']
      mapped[:last_name] = args['last_name'] if args['last_name']
      mapped[:email] = args['email'] if args['email']
      mapped[:date_of_birth] = parse_date(args['date_of_birth']) if args['date_of_birth']
      
      # Handle height conversion and detect units preference
      height_units = nil
      if args['height']
        height_cm, height_units = convert_height_to_cm_with_units(args['height'])
        mapped[:height_cm] = height_cm
      end
      
      # Handle weight conversion and detect units preference
      weight_units = nil
      if args['weight']
        weight_kg, weight_units = convert_weight_to_kg_with_units(args['weight'])
        mapped[:weight_kg] = weight_kg
      end
      
      # Set units preference based on what the user provided
      mapped[:units_preference] = determine_units_preference(height_units, weight_units)
      
      mapped[:activity_level] = args['activity_level'] if args['activity_level']
      mapped[:biological_sex] = args['biological_sex'] if args['biological_sex']
      mapped[:health_goals] = args['health_goals'] if args['health_goals']
      mapped[:health_conditions] = args['health_conditions'] if args['health_conditions']
      
      mapped.compact
    end

    def parse_date(date_str)
      Date.parse(date_str) if date_str
    rescue ArgumentError
      nil
    end

    def convert_height_to_cm_with_units(height_str)
      return [nil, nil] unless height_str
      
      # Convert various height formats to cm and detect units
      if height_str.match(/(\d+)\s*(?:feet?|ft|')\s*(\d+)\s*(?:inches?|in|")?/i)
        # e.g., "5 feet 6 inches", "5ft 6in", "5'6\""
        feet = $1.to_i
        inches = $2.to_i
        total_inches = (feet * 12) + inches
        [(total_inches * 2.54).round, 'imperial']
      elsif height_str.match(/(\d+)\s*(?:feet?|ft|')/i)
        # e.g., "5 feet", "5ft", "5'"
        feet = $1.to_i
        [(feet * 12 * 2.54).round, 'imperial']
      elsif height_str.match(/(\d+)\s*(?:inches?|in|")/i)
        # e.g., "66 inches", "66in", "66\""
        inches = $1.to_i
        [(inches * 2.54).round, 'imperial']
      elsif height_str.match(/(\d+)\s*cm/i)
        # e.g., "168 cm"
        [$1.to_i, 'metric']
      elsif height_str.match(/(\d+\.?\d*)\s*m/i)
        # e.g., "1.68 m"
        [($1.to_f * 100).round, 'metric']
      else
        # Try to parse as a simple number (assume cm)
        value = height_str.to_f.round if height_str.match(/\d/)
        [value, 'metric']
      end
    end

    def convert_weight_to_kg_with_units(weight_str)
      return [nil, nil] unless weight_str
      
      # Convert various weight formats to kg and detect units
      if weight_str.match(/(\d+\.?\d*)\s*(?:pounds?|lbs?|lb)/i)
        # e.g., "140 pounds", "140lbs", "140 lb"
        pounds = $1.to_f
        [(pounds * 0.453592).round(1), 'imperial']
      elsif weight_str.match(/(\d+\.?\d*)\s*kg/i)
        # e.g., "65 kg"
        [$1.to_f, 'metric']
      else
        # Try to parse as a simple number (assume kg)
        value = weight_str.to_f if weight_str.match(/\d/)
        [value, 'metric']
      end
    end

    def determine_units_preference(height_units, weight_units)
      # If either measurement was imperial, prefer imperial
      if height_units == 'imperial' || weight_units == 'imperial'
        'imperial'
      else
        'metric'
      end
    end

    # Legacy methods for backward compatibility
    def convert_height_to_cm(height_str)
      value, _ = convert_height_to_cm_with_units(height_str)
      value
    end

    def convert_weight_to_kg(weight_str)
      value, _ = convert_weight_to_kg_with_units(weight_str)
      value
    end
  end
end 
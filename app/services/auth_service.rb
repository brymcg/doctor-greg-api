class AuthService
  class InvalidToken < StandardError; end
  class ExpiredToken < StandardError; end

  JWT_SECRET = Rails.application.credentials.secret_key_base || 'fallback_secret'
  JWT_ALGORITHM = 'HS256'
  TOKEN_EXPIRATION = 30.days

  class << self
    def generate_token(user)
      payload = {
        user_id: user.id,
        email: user.email,
        exp: TOKEN_EXPIRATION.from_now.to_i,
        iat: Time.current.to_i
      }
      
      JWT.encode(payload, JWT_SECRET, JWT_ALGORITHM)
    end

    def decode_token(token)
      return nil unless token

      begin
        decoded = JWT.decode(token, JWT_SECRET, true, { algorithm: JWT_ALGORITHM })
        payload = decoded[0]
        
        # Check if token is expired
        if payload['exp'] < Time.current.to_i
          raise ExpiredToken, 'Token has expired'
        end
        
        payload
      rescue JWT::DecodeError => e
        raise InvalidToken, "Invalid token: #{e.message}"
      rescue JWT::ExpiredSignature
        raise ExpiredToken, 'Token has expired'
      end
    end

    def authenticate_user(email, password)
      return nil unless email && password
      user = User.find_by(email: email.downcase.strip)
      return nil unless user&.authenticate(password)
      
      user
    end

    def current_user_from_token(token)
      return nil unless token
      
      payload = decode_token(token)
      User.find_by(id: payload['user_id'])
    rescue InvalidToken, ExpiredToken
      nil
    end

    def extract_token_from_header(authorization_header)
      return nil unless authorization_header

      # Expected format: "Bearer <token>"
      token_match = authorization_header.match(/^Bearer\s+(.+)$/i)
      token_match&.captures&.first
    end

    def refresh_token(token)
      payload = decode_token(token)
      user = User.find_by(id: payload['user_id'])
      
      return nil unless user
      
      generate_token(user)
    rescue InvalidToken, ExpiredToken
      nil
    end
  end
end 
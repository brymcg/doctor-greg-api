class Api::V1::AuthController < ApplicationController
  before_action :authenticate_user!, only: [:me, :logout, :refresh]

  def login
    user = AuthService.authenticate_user(params[:email], params[:password])
    
    if user
      token = AuthService.generate_token(user)
      render json: {
        user: user_data(user),
        token: token,
        expires_at: 30.days.from_now.iso8601
      }, status: :ok
    else
      render json: {
        error: 'Invalid email or password'
      }, status: :unauthorized
    end
  end

  def register
    user = User.new(user_params)
    
    if user.save
      token = AuthService.generate_token(user)
      render json: {
        user: user_data(user),
        token: token,
        expires_at: 30.days.from_now.iso8601
      }, status: :created
    else
      render json: {
        errors: user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def logout
    # With JWT, logout is handled client-side by removing the token
    # Optionally, we could implement a token blacklist here
    render json: { message: 'Logged out successfully' }, status: :ok
  end

  def me
    render json: {
      user: user_data(current_user)
    }, status: :ok
  end

  def refresh
    new_token = AuthService.refresh_token(current_token)
    
    if new_token
      render json: {
        token: new_token,
        expires_at: 30.days.from_now.iso8601
      }, status: :ok
    else
      render json: {
        error: 'Unable to refresh token'
      }, status: :unauthorized
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :first_name, :last_name)
  end

  def user_data(user)
    {
      id: user.id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      date_of_birth: user.date_of_birth,
      height_cm: user.height_cm,
      weight_kg: user.weight_kg,
      activity_level: user.activity_level,
      biological_sex: user.biological_sex,
      onboarded: user_onboarded?(user),
      created_at: user.created_at,
      updated_at: user.updated_at
    }
  end

  def user_onboarded?(user)
    required_fields = %w[first_name email date_of_birth height_cm weight_kg activity_level]
    required_fields.all? { |field| user.send(field).present? }
  end

  def authenticate_user!
    token = AuthService.extract_token_from_header(request.headers['Authorization'])
    @current_user = AuthService.current_user_from_token(token)
    @current_token = token

    unless @current_user
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end

  def current_user
    @current_user
  end

  def current_token
    @current_token
  end
end 
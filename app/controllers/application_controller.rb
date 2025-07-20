class ApplicationController < ActionController::API
  def health
    render json: { 
      status: 'ok', 
      service: 'Doctor Greg API',
      version: '1.0.0',
      timestamp: Time.current.iso8601
    }
  end
end 
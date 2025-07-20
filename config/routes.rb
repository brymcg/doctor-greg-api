Rails.application.routes.draw do
  # Health check
  get 'health', to: 'application#health'
  
  # Terra webhooks
  namespace :webhooks do
    post 'terra', to: 'terra#receive'
  end
  
  # API routes
  namespace :api do
    namespace :v1 do
      # Authentication
      post 'auth/login', to: 'auth#login'
      post 'auth/register', to: 'auth#register'
      delete 'auth/logout', to: 'auth#logout'
      get 'auth/me', to: 'auth#me'
      post 'auth/refresh', to: 'auth#refresh'
      
      # Chat - handles everything contextually
      post 'chat/message', to: 'chat#send_message'
      get 'chat/conversations', to: 'chat#conversations'
      post 'chat/conversation', to: 'chat#new_conversation'
      
      # Terra integration
      get 'terra/auth_url', to: 'terra#auth_url'
      post 'terra/connect', to: 'terra#connect'
      get 'terra/connections', to: 'terra#connections'
      delete 'terra/disconnect', to: 'terra#disconnect'
      get 'terra/data', to: 'terra#user_data'
    end
  end
end 
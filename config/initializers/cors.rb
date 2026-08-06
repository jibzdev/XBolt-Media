Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'  # In production, specify your app's domain
    
    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ['Authorization']
  end
end 
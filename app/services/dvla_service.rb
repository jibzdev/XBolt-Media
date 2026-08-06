class DvlaService
  include HTTParty
  
  # Rate limiting constants
  MAX_REQUESTS_PER_MINUTE = 10
  MAX_REQUESTS_PER_HOUR = 100
  
  def initialize
    # Primary API - DVLA Open Data API
    @dvla_open_data_api_key = ENV['DVLA_OPEN_DATA_API_KEY']
    
    # Secondary API - MOT History API (for detailed MOT data)
    @dvla_mot_client_id = ENV['DVLA_MOT_CLIENT_ID']
    @dvla_mot_client_secret = ENV['DVLA_MOT_CLIENT_SECRET']
    @dvla_mot_scope_url = ENV['DVLA_MOT_SCOPE_URL']
    @dvla_mot_token_url = ENV['DVLA_MOT_TOKEN_URL']
  end
  
  def lookup_vehicle(registration_number, user_ip = nil)
    # Rate limiting check
    if user_ip && rate_limited?(user_ip)
      return { success: false, error: 'Rate limit exceeded. Please try again later.' }
    end
    
    # Validate and clean the registration number
    clean_registration = validate_and_clean_registration(registration_number)
    return { success: false, error: 'Invalid registration number format' } unless clean_registration
    
    Rails.logger.info "DVLA Service: Looking up #{clean_registration}"
    
    # Record the request for rate limiting
    record_request(user_ip) if user_ip
    
    # Try DVLA Open Data API first (most reliable)
    if @dvla_open_data_api_key.present?
      result = try_dvla_open_data_api(clean_registration)
      return result if result[:success]
    end
    
    # Fallback to MOT API if available
    if @dvla_mot_client_id.present?
      result = try_dvla_mot_api(clean_registration)
      return result if result[:success]
    end
    
    # Return fallback data if no APIs work
    {
      success: true,
      vehicle: {
        make: 'Unknown',
        year: 'Pending',
        colour: 'API Lookup'
      },
      registration: clean_registration,
      note: 'Vehicle details will be retrieved automatically when API is configured'
    }
  end
  
  private
  
  def validate_and_clean_registration(registration)
    return nil if registration.blank?
    
    # Clean and format the registration
    clean_reg = registration.to_s.upcase.gsub(/[^A-Z0-9]/, '')
    
    # UK registration plate validation (basic format check)
    # Format: 1-3 letters, 1-3 numbers, 1-3 letters (e.g., AB12CDE, ABC123D, A1BCD)
    return nil unless clean_reg.match?(/\A[A-Z]{1,3}[0-9]{1,3}[A-Z]{1,3}\z/)
    
    # Additional length check (UK plates are typically 5-7 characters)
    return nil unless clean_reg.length.between?(5, 7)
    
    clean_reg
  end
  
  def rate_limited?(user_ip)
    # Check Redis or database for rate limiting
    # For now, use a simple in-memory cache (replace with Redis in production)
    cache_key = "dvla_requests:#{user_ip}"
    requests = Rails.cache.read(cache_key) || []
    
    # Remove requests older than 1 hour
    one_hour_ago = 1.hour.ago
    requests = requests.select { |time| time > one_hour_ago }
    
    # Check if user has exceeded limits
    requests.count >= MAX_REQUESTS_PER_HOUR
  end
  
  def record_request(user_ip)
    cache_key = "dvla_requests:#{user_ip}"
    requests = Rails.cache.read(cache_key) || []
    requests << Time.current
    
    # Keep only last hour of requests
    one_hour_ago = 1.hour.ago
    requests = requests.select { |time| time > one_hour_ago }
    
    Rails.cache.write(cache_key, requests, expires_in: 1.hour)
  end
  
  def try_dvla_open_data_api(registration)
    Rails.logger.info "DVLA Service: Trying Open Data API for #{registration}"
    
    headers = {
      'x-api-key' => @dvla_open_data_api_key,
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
    
    begin
      url = "https://driver-vehicle-licensing.api.gov.uk/vehicle-enquiry/v1/vehicles"
      body = { registrationNumber: registration }.to_json
      
      Rails.logger.info "DVLA Service: Making POST request to #{url}"
      
      response = self.class.post(url, headers: headers, body: body, timeout: 10)
      
      Rails.logger.info "DVLA Service: Response code: #{response.code}"
      
      case response.code
      when 200
        result = parse_dvla_open_data(response.parsed_response)
        Rails.logger.info "DVLA Service: Parsed result: #{result.inspect}"
        result
      when 404
        Rails.logger.info "DVLA Service: Vehicle not found"
        { success: false, error: 'Vehicle not found' }
      when 400
        Rails.logger.info "DVLA Service: Invalid registration format"
        { success: false, error: 'Invalid registration number format' }
      when 401
        Rails.logger.info "DVLA Service: Invalid API credentials"
        { success: false, error: 'Invalid DVLA Open Data API credentials' }
      when 403
        Rails.logger.info "DVLA Service: Forbidden - check API key"
        { success: false, error: 'DVLA API access forbidden - check API key' }
      when 429
        Rails.logger.info "DVLA Service: Rate limit exceeded"
        { success: false, error: 'DVLA rate limit exceeded' }
      else
        Rails.logger.info "DVLA Service: Unexpected response code #{response.code}"
        { success: false, error: 'DVLA Open Data service unavailable' }
      end
    rescue => e
      Rails.logger.error "DVLA Open Data API Error: #{e.message}"
      { success: false, error: 'DVLA Open Data service error' }
    end
  end

  def try_dvla_mot_api(registration)
    # This uses the MOT History API with OAuth2 authentication
    # First get the access token
    token_response = get_mot_api_token
    
    return { success: false, error: 'Failed to get MOT API token' } unless token_response[:success]
    
    headers = {
      'Authorization' => "Bearer #{token_response[:token]}",
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
    
    begin
      response = self.class.get(
        "https://beta.check-mot.service.gov.uk/trade/vehicles/mot-tests?registration=#{registration}",
        headers: headers,
        timeout: 10
      )
      
      case response.code
      when 200
        parse_dvla_mot_data(response.parsed_response)
      when 404
        { success: false, error: 'Vehicle not found' }
      when 400
        { success: false, error: 'Invalid registration number format' }
      when 401
        { success: false, error: 'Invalid MOT API credentials' }
      when 429
        { success: false, error: 'MOT API rate limit exceeded' }
      else
        { success: false, error: 'MOT API service unavailable' }
      end
    rescue => e
      Rails.logger.error "DVLA MOT API Error: #{e.message}"
      { success: false, error: 'DVLA MOT service error' }
    end
  end

  def get_mot_api_token
    # Get OAuth2 token for MOT API
    token_data = {
      client_id: @dvla_mot_client_id,
      client_secret: @dvla_mot_client_secret,
      scope: @dvla_mot_scope_url,
      grant_type: 'client_credentials'
    }
    
    begin
      response = self.class.post(
        @dvla_mot_token_url,
        body: token_data,
        timeout: 10
      )
      
      if response.code == 200
        token_response = response.parsed_response
        { success: true, token: token_response['access_token'] }
      else
        Rails.logger.error "MOT API Token Error: #{response.code} - #{response.body}"
        { success: false, error: 'Failed to get MOT API token' }
      end
    rescue => e
      Rails.logger.error "MOT API Token Error: #{e.message}"
      { success: false, error: 'MOT API token service error' }
    end
  end

  def parse_dvla_open_data(data)
    {
      success: true,
      vehicle: {
        make: data['make'],
        year: extract_year(data['yearOfManufacture']),
        colour: data['primaryColour'] || data['colour'] || 'Unknown',
        fuel_type: data['fuelType'],
        engine_capacity: data['engineCapacity'],
        co2_emissions: data['co2Emissions'],
        tax_status: data['taxStatus'],
        mot_status: data['motStatus'],
        mot_expiry: data['motExpiryDate'],
        tax_due_date: data['taxDueDate']
      },
      registration: data['registrationNumber']
    }
  end

  def parse_dvla_mot_data(data)
    # MOT API returns array of MOT tests, get the most recent one
    latest_mot = data.first
    
    {
      success: true,
      vehicle: {
        make: latest_mot['make'],
        year: extract_year(latest_mot['firstUsedDate']&.split('-')&.first),
        colour: latest_mot['primaryColour'],
        fuel_type: latest_mot['fuelType'],
        engine_capacity: latest_mot['engineCapacity'],
        mot_status: latest_mot['motTestExpiryDate'] ? 'Valid' : 'Expired',
        mot_expiry: latest_mot['motTestExpiryDate'],
        mot_tests: data.length
      },
      registration: latest_mot['registration']
    }
  end
  
  def extract_year(year_data)
    return nil unless year_data
    
    # Handle different year formats from different APIs
    if year_data.is_a?(String)
      year_data.to_i
    elsif year_data.is_a?(Integer)
      year_data
    else
      nil
    end
  end
end
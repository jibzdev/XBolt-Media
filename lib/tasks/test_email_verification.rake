namespace :auth do
  desc "Test email verification system"
  task test_email_verification: :environment do
    puts "Testing Email Verification System..."
    puts "=" * 50
    
    # Test user creation with unverified status
    test_email = "verify_test_#{rand(1000)}@example.com"
    test_username = "verifyuser#{rand(1000)}"
    
    puts "Creating unverified test user..."
    puts "  Email: #{test_email}"
    puts "  Username: #{test_username}"
    
    begin
      user = User.new(
        username: test_username,
        email: test_email,
        password: "password123",
        password_confirmation: "password123"
      )
      
      if user.save
        puts "✅ User created successfully"
        puts "  ID: #{user.id}"
        puts "  Status: #{user.status}"
        puts "  Verification token: #{user.verification_token.present? ? 'SET' : 'NOT SET'}"
        
        # Test dashboard access restriction
        puts "\nTesting dashboard access restriction..."
        if user.status != 'verified'
          puts "✅ Unverified user correctly blocked from dashboard"
        else
          puts "❌ Unverified user should be blocked from dashboard"
        end
        
        # Test verification token generation
        puts "\nTesting verification token generation..."
        user.generate_verification_token!
        puts "✅ Verification token generated"
        puts "  Token: #{user.verification_token[0..10]}..."
        puts "  Sent at: #{user.verification_sent_at}"
        
        # Test token validation
        puts "\nTesting token validation..."
        if user.verification_token_valid?
          puts "✅ Token is valid"
        else
          puts "❌ Token is invalid"
        end
        
        # Test 2-minute cooldown
        puts "\nTesting 2-minute cooldown..."
        if user.verification_sent_at && Time.current < user.verification_sent_at + 2.minutes
          time_left = ((user.verification_sent_at + 2.minutes) - Time.current).to_i
          puts "✅ Cooldown active: #{time_left} seconds remaining"
        else
          puts "❌ Cooldown should be active"
        end
        
        # Test email verification
        puts "\nTesting email verification..."
        user.verify_email!
        puts "✅ Email verified"
        puts "  Status: #{user.status}"
        puts "  Token cleared: #{user.verification_token.blank? ? 'YES' : 'NO'}"
        
        # Test dashboard access after verification
        puts "\nTesting dashboard access after verification..."
        if user.status == 'verified'
          puts "✅ Verified user can access dashboard"
        else
          puts "❌ Verified user should be able to access dashboard"
        end
        
        # Clean up
        user.destroy
        puts "\n✅ Test user cleaned up"
        
      else
        puts "❌ User creation failed:"
        user.errors.full_messages.each do |error|
          puts "  - #{error}"
        end
      end
      
    rescue => e
      puts "❌ Email verification test failed: #{e.message}"
    end
    
    puts "=" * 50
    puts "Email verification test completed!"
  end
end

# Initialize default SEO settings
puts "Initializing default SEO settings..."
SeoSetting.initialize_defaults
puts "SEO settings initialized successfully!"

# Initialize general settings if they don't exist
if GeneralSetting.count == 0
  puts "Creating default general settings..."
  GeneralSetting.create!(
    application_name: "XBolt",
    phone_number: "+447459731426",
    contact_email: "xboltmedia@gmail.com",
    website_url: "https://xboltmedia.com"
  )
  puts "General settings created successfully!"
end

# Create sample services
puts "Creating services..."
services = [
  { name: 'Website Build', base_price: 1500.00, category: 'Web', description: 'End-to-end website design and development', active: true, position: 1 },
  { name: 'Landing Page', base_price: 500.00, category: 'Web', description: 'High-converting landing page for campaigns', active: true, position: 2 },
  { name: 'SEO Setup', base_price: 300.00, category: 'Marketing', description: 'Technical SEO setup and on-page basics', active: true, position: 3 },
  { name: 'Maintenance', base_price: 150.00, category: 'Support', description: 'Updates, fixes, and ongoing support', active: true, position: 4 },
  { name: 'Branding', base_price: 800.00, category: 'Design', description: 'Visual identity and brand assets', active: true, position: 5 }
]

services.each do |service_attrs|
  Service.find_or_create_by!(name: service_attrs[:name]) do |service|
    service.base_price = service_attrs[:base_price]
    service.category = service_attrs[:category]
    service.description = service_attrs[:description]
    service.active = service_attrs[:active]
    service.position = service_attrs[:position]
  end
end

puts "Services created successfully!"

# Create admin user (username-based)
admin_password = ENV["ADMIN_PASSWORD"].presence
if admin_password.blank?
  if Rails.env.production?
    raise "ADMIN_PASSWORD must be set when seeding in production"
  end
  admin_password = SecureRandom.base58(20)
  puts "ADMIN_PASSWORD not set; generated a one-time password for local/dev:"
  puts "  username: admin"
  puts "  password: #{admin_password}"
end

admin = User.find_or_initialize_by(username: "admin")
admin.assign_attributes(
  password: admin_password,
  password_confirmation: admin_password,
  admin: true,
  admin_role: "super_admin",
  status: "verified"
)
admin.email ||= "admin@admin.com"
admin.save!

puts "Admin user ensured successfully!"

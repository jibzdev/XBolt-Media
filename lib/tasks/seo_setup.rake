namespace :seo do
  desc "Set up SEO system and initialize default settings"
  task setup: :environment do
    puts "Setting up SEO system..."
    
    # Check if we need to add the new columns
    unless SeoSetting.column_names.include?('author')
      puts "Adding new SEO columns..."
      
      # Add new columns one by one
      ActiveRecord::Base.connection.add_column :seo_settings, :author, :string
      ActiveRecord::Base.connection.add_column :seo_settings, :robots, :string, default: 'index, follow'
      ActiveRecord::Base.connection.add_column :seo_settings, :og_type, :string, default: 'website'
      ActiveRecord::Base.connection.add_column :seo_settings, :og_url, :string
      ActiveRecord::Base.connection.add_column :seo_settings, :og_title, :string
      ActiveRecord::Base.connection.add_column :seo_settings, :og_description, :text
      ActiveRecord::Base.connection.add_column :seo_settings, :og_image, :string
      ActiveRecord::Base.connection.add_column :seo_settings, :twitter_card, :string, default: 'summary_large_image'
      ActiveRecord::Base.connection.add_column :seo_settings, :twitter_url, :string
      ActiveRecord::Base.connection.add_column :seo_settings, :twitter_title, :string
      ActiveRecord::Base.connection.add_column :seo_settings, :twitter_description, :text
      ActiveRecord::Base.connection.add_column :seo_settings, :twitter_image, :string
      ActiveRecord::Base.connection.add_column :seo_settings, :favicon_url, :string
      ActiveRecord::Base.connection.add_column :seo_settings, :apple_touch_icon_url, :string
      ActiveRecord::Base.connection.add_column :seo_settings, :canonical_url, :string
      ActiveRecord::Base.connection.add_column :seo_settings, :structured_data, :text
      
      puts "New columns added successfully!"
    end
    
    # Initialize default SEO settings
    puts "Initializing default SEO settings..."
    SeoSetting.initialize_defaults
    puts "SEO settings initialized successfully!"
    
    puts "SEO system setup complete!"
  end
  
  desc "Reset SEO settings to defaults"
  task reset: :environment do
    puts "Resetting SEO settings..."
    SeoSetting.destroy_all
    SeoSetting.initialize_defaults
    puts "SEO settings reset successfully!"
  end
end

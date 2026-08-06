# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"
# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.

# Add video files to asset pipeline
Rails.application.config.assets.precompile += %w( *.mp4 *.avi *.mov *.wmv *.flv *.webm )

# Add videos directory to asset paths
Rails.application.config.assets.paths << Rails.root.join('app', 'assets', 'videos')

# Ensure tailwind.css is precompiled
Rails.application.config.assets.precompile += %w( tailwind.css )
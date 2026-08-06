Rails.application.routes.draw do
  # Demo website host (example.xboltmedia.com / example.localhost)
  constraints(lambda { |req|
    host = req.host.to_s.downcase
    host.start_with?("example.") || host == "example.localhost" || host == "example.lvh.me"
  }) do
    # Keep media links reachable on preview host before catch-all.
    get '/media/*key', to: 'asset_links#show', as: nil, format: false
    get "/", to: "demo_website#show", as: nil
    match "(*path)", to: "demo_website#show", via: :get, as: nil
  end

  # Themed error pages (used by config.exceptions_app)
  match '/404', to: 'errors#not_found', via: :all
  match '/422', to: 'errors#unprocessable_entity', via: :all
  match '/500', to: 'errors#internal_server_error', via: :all
  get '/media/*key', to: 'asset_links#show', as: :media_asset, format: false
  get '/tenants/:tenant_id/assets', to: 'tenant_assets#index', as: :tenant_assets_for_business

  # Tenant websites (subdomain / custom domain). Serve arbitrary paths.
  # IMPORTANT: This must come BEFORE the normal app routes, otherwise tenant hosts
  # will match the main landing routes and show the host site instead of the tenant site.
  constraints TenantConstraint.new do
    post '/contact', to: 'tenant_sites#contact_submit', as: nil
    post '/xbolt/events', to: 'tenant_events#create', as: nil
    get '/xbolt/gallery.json', to: 'tenant_assets#index', as: nil
    get '/sitemap.xml', to: 'sitemaps#tenant', as: nil, format: :xml
    get '/media/*key', to: 'asset_links#show', as: nil, format: false
    # IMPORTANT: format: false prevents Rails from stripping extensions into params[:format]
    # (e.g. /assets/logo.png), which breaks static file resolution.
    # Route ALL methods on tenant hosts to tenant serving.
    # This prevents tenant static sites from accidentally POSTing into Rails app endpoints
    # (which causes CSRF 422 errors).
    match '(*path)', to: 'tenant_sites#show', as: :tenant_root, via: :all, format: false
  end

  # Landing routes
  root 'landing#index'
  get '/about', to: 'landing#about', as: 'about'
  get '/services', to: 'landing#services', as: 'services'
  get '/contact', to: 'landing#contact', as: 'contact'
  post '/contact', to: 'landing#contact_submit', as: 'contact_submit'
  get '/work', to: 'landing#work', as: 'work'
  get '/reviews', to: 'landing#reviews', as: 'reviews'
  get '/terms-of-service', to: 'landing#terms_of_service', as: 'terms_of_service'
  get '/privacy-policy', to: 'landing#privacy_policy', as: 'privacy_policy'
  get '/sitemap.xml', to: 'sitemaps#show', as: :sitemap, format: :xml

  # Auth routes
  get '/auth/login', to: 'auth#login', as: 'login'
  post '/auth/login', to: 'auth#login_handle'
  get '/auth/logout', to: 'auth#logout', as: 'logout'
  post '/auth/stop-impersonating', to: 'auth#stop_impersonating', as: 'stop_impersonating'
  get '/auth/forgot-password', to: 'auth#forgot_password', as: 'forgot_password'
  post '/auth/forgot-password', to: 'auth#forgot_password_handle'
  get '/auth/forgot-password-sent', to: 'auth#forgot_password_sent', as: 'forgot_password_sent'
  get '/auth/reset-password/:token', to: 'auth#edit_reset_password', as: 'edit_reset_password'
  post '/auth/reset-password', to: 'auth#update_reset_password', as: 'update_reset_password'

  # Legacy admin URL redirects (admin panel is now under /dashboard)
  get '/admin', to: redirect('/dashboard')
  get '/admin/*path', to: redirect('/dashboard/%{path}')

  # Admin routes (admin panel lives under /dashboard)
  namespace :admin, path: 'dashboard' do
    get '/', to: 'dashboard#overview', as: 'dashboard'
    get '/overview', to: 'dashboard#overview', as: 'overview'
    resource :demo_website, only: [:show, :update], controller: 'demo_websites'
    resources :assets, only: [:index, :create, :update, :destroy]
    get '/website', to: 'tenant_site_builder#index', as: :website
    post '/website/publish', to: 'tenant_site_builder#publish', as: :publish_website
    patch '/website/static', to: 'tenant_site_builder#static_update', as: :static_website_update
    get '/website/static/preview', to: 'tenant_site_builder#static_preview', as: :static_website_preview
    get '/website/static/assets/*path', to: 'tenant_site_builder#static_asset', as: :static_website_asset
    resources :website_pages, path: 'website/pages', controller: 'tenant_site_builder', except: [:index, :show] do
      member do
        get :preview
      end
    end
    
    resources :services, except: [:show] do
      collection do
        patch :reorder
      end
    end
    
    resources :users do
      member do
        post :impersonate
      end
    end

    resources :messages, only: [:index, :show, :destroy] do
      collection do
        delete :prune
      end
      member do
        patch :mark_read
      end
    end
    resource :account, only: [] do
      get :password, to: 'account#edit_password'
      patch :password, to: 'account#update_password'
    end
    resources :ip_bans, only: [:index, :create, :destroy], path: 'ip-bans'

    resources :businesses, only: [:index, :new, :create, :show, :edit, :update, :destroy] do
      member do
        post :verify_custom_domain
        post :install_sitemap
        post :install_watermark
        post :deploy_site
        delete :delete_site
        get :download_site_zip
        post :create_business_login
        post :reset_business_password
      end
    end
    resources :work_cards, only: [:index, :new, :create, :edit, :update, :destroy]
    resources :reviews, only: [:index, :new, :create, :edit, :update, :destroy]
    resources :invoices, only: [:index, :new, :create, :show, :edit, :update, :destroy] do
      member do
        get :download_pdf
        post :regenerate_share_token
      end
    end

    get '/settings', to: 'settings#index', as: 'settings'
    patch '/settings', to: 'settings#update', as: 'update_settings'
    resource :theme, only: [:edit, :update], controller: 'themes'
    
    # Additional admin routes
    resources :seo_settings
    post '/seo_settings/initialize_defaults', to: 'seo_settings#initialize_defaults', as: 'initialize_seo_defaults'
    get '/activity/live', to: 'dashboard#activity_live_view', as: 'activity_live_view'
    get '/analytics/page-insights', to: 'dashboard#page_insights', as: 'page_insights'
  end

  # Public invoice share links
  get '/invoices/share/:token', to: 'invoice_shares#show', as: 'shared_invoice'
  get '/invoices/share/:token/pdf', to: 'invoice_shares#download_pdf', as: 'shared_invoice_pdf'

  # Email verification routes
  get 'verify_email/:token', to: 'auth#verify_email', as: 'verify_email'
  get 'verify_email', to: 'auth#verify_email_page', as: 'verify_email_page'
  post 'resend_verification_email', to: 'auth#resend_verification_email', as: 'resend_verification_email'



  # Misc routes
  post '/application/upload_image', to: 'application#upload_image', as: 'upload_image'
end

# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2026_07_28_001100) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "activities", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_activities_on_user_id"
  end

  create_table "banned_ips", force: :cascade do |t|
    t.string "ip_address", null: false
    t.text "reason"
    t.integer "banned_by_id"
    t.datetime "last_seen_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["banned_by_id"], name: "index_banned_ips_on_banned_by_id"
    t.index ["ip_address"], name: "index_banned_ips_on_ip_address", unique: true
  end

  create_table "bookings", force: :cascade do |t|
    t.integer "user_id"
    t.string "service_type", null: false
    t.string "vehicle_make", default: "Unknown", null: false
    t.string "vehicle_model"
    t.integer "vehicle_year", null: false
    t.string "vehicle_color"
    t.text "special_requests"
    t.datetime "appointment_date", null: false
    t.decimal "estimated_cost", precision: 10, scale: 2
    t.decimal "final_cost", precision: 10, scale: 2
    t.string "status", default: "pending"
    t.string "customer_name"
    t.string "customer_email"
    t.string "customer_phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "license_plate"
    t.integer "engine_capacity"
    t.index ["appointment_date"], name: "index_bookings_on_appointment_date"
    t.index ["service_type"], name: "index_bookings_on_service_type"
    t.index ["status"], name: "index_bookings_on_status"
    t.index ["user_id"], name: "index_bookings_on_user_id"
  end

  create_table "businesses", force: :cascade do |t|
    t.string "name", null: false
    t.string "subdomain", null: false
    t.string "custom_domain"
    t.string "custom_domain_status", default: "unverified", null: false
    t.string "domain_verification_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.string "image_url"
    t.boolean "active", default: false, null: false
    t.string "tenant_contact_sender_email"
    t.string "tenant_contact_sender_password"
    t.string "tenant_contact_recipient_email"
    t.index ["active"], name: "index_businesses_on_active"
    t.index ["custom_domain"], name: "index_businesses_on_custom_domain", unique: true
    t.index ["subdomain"], name: "index_businesses_on_subdomain", unique: true
  end

  create_table "contact_messages", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "phone"
    t.text "message", null: false
    t.string "ip_address", null: false
    t.string "user_agent"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "business_id"
    t.index ["business_id", "ip_address", "created_at"], name: "index_contact_messages_on_business_ip_and_created"
    t.index ["business_id"], name: "index_contact_messages_on_business_id"
    t.index ["created_at"], name: "index_contact_messages_on_created_at"
    t.index ["ip_address", "created_at"], name: "index_contact_messages_on_ip_address_and_created_at"
    t.index ["read_at"], name: "index_contact_messages_on_read_at"
  end

  create_table "demo_website_settings", force: :cascade do |t|
    t.string "site_title", default: "Your Business Name", null: false
    t.string "hero_badge", default: "Template Preview", null: false
    t.string "hero_heading", default: "Your business, beautifully presented", null: false
    t.text "hero_subheading", default: "Show clients how their future website could look with your service.", null: false
    t.string "cta_primary_text", default: "Get Quote", null: false
    t.string "cta_secondary_text", default: "View Work", null: false
    t.string "about_title", default: "About Your Business", null: false
    t.text "about_body", default: "Replace this with business-specific details in the admin dashboard.", null: false
    t.string "theme_name", default: "violet", null: false
    t.string "contact_email", default: "you@example.com", null: false
    t.string "contact_phone", default: "+44 7000 000000", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "layout_name", default: "show", null: false
    t.string "services_title", default: "Our Services", null: false
    t.text "services_intro", default: "Comprehensive solutions tailored for your business.", null: false
    t.string "work_title", default: "Our Work", null: false
    t.text "work_intro", default: "Recent projects showcasing quality and attention to detail.", null: false
    t.string "testimonials_title", default: "What Our Clients Say", null: false
    t.text "testimonials_intro", default: "Real feedback from happy clients.", null: false
    t.string "faq_title", default: "Frequently Asked Questions", null: false
    t.text "faq_intro", default: "Answers to common questions about our services.", null: false
    t.string "contact_title", default: "Let's Work Together", null: false
    t.text "contact_intro", default: "Ready to get started? Get in touch for a free quote.", null: false
    t.text "feature_cards_data", default: "Fast Delivery|Quick turnaround times without compromising quality.\nQuality Assured|Every project undergoes rigorous quality checks.\nBest Value|Transparent pricing and excellent value.\nConsultancy & Design|Expert planning, consultation, and support.", null: false
    t.text "project_cards_data", default: "Project One|Featured Project|Professional work showcasing quality and detail.\nProject Two|Featured Project|Professional work showcasing quality and detail.\nProject Three|Featured Project|Professional work showcasing quality and detail.\nProject Four|Featured Project|Professional work showcasing quality and detail.\nProject Five|Featured Project|Professional work showcasing quality and detail.\nProject Six|Featured Project|Professional work showcasing quality and detail.", null: false
    t.text "testimonial_cards_data", default: "John Doe|Business Owner|Absolutely outstanding work and communication.\nSarah Miller|Homeowner|The process was smooth and the result was perfect.\nMichael Johnson|Property Manager|Professional from start to finish.", null: false
    t.text "faq_items_data", default: "How long does a project take?|Most projects are completed within 2-4 weeks depending on scope.\nDo you offer free consultations?|Yes, we offer free initial consultations.\nWhat areas do you service?|We serve local and surrounding areas.\nWhat payment methods do you accept?|Bank transfer, card, and cash are supported.\nDo you provide warranties?|Yes, all work includes a warranty.\nHow do I get started?|Send us a message and we will guide you through the next steps.", null: false
    t.text "stat_items_data", default: "100%|Satisfaction\n500+|Projects\n24/7|Support\n10+|Years", null: false
    t.text "process_steps_data", default: "Discovery|We learn your goals and requirements.\nDesign|We craft a clear visual direction.\nBuild|We deliver a polished, high-quality result.\nLaunch|We deploy and support your launch.", null: false
    t.integer "tenant_image_business_id"
    t.text "image_slots_data", default: "", null: false
  end

  create_table "general_settings", force: :cascade do |t|
    t.string "application_name", default: "XBolt"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "maintenance_mode"
    t.string "phone_number"
    t.string "contact_email"
    t.string "website_url"
    t.string "logo_url"
    t.string "favicon_url"
    t.string "theme_primary", default: "#f59e0b", null: false
    t.string "theme_primary_hover", default: "#fbbf24", null: false
    t.string "theme_on_primary", default: "#09090b", null: false
    t.string "theme_bg", default: "#09090b", null: false
    t.string "theme_surface", default: "#111113", null: false
    t.string "theme_surface_alt", default: "#0a0a0c", null: false
    t.string "theme_border", default: "#27272a", null: false
    t.string "theme_text", default: "#ffffff", null: false
    t.string "theme_text_muted", default: "#71717a", null: false
    t.string "linkedin_url"
    t.string "facebook_url"
    t.string "instagram_url"
    t.string "tiktok_url"
    t.string "google_reviews_url"
  end

  create_table "invoices", force: :cascade do |t|
    t.integer "business_id", null: false
    t.integer "created_by_id"
    t.string "invoice_number", null: false
    t.string "status", default: "draft", null: false
    t.date "issue_date", null: false
    t.date "due_date", null: false
    t.json "line_items", default: [], null: false
    t.decimal "subtotal", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "total", precision: 12, scale: 2, default: "0.0", null: false
    t.text "notes"
    t.string "share_token", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id"], name: "index_invoices_on_business_id"
    t.index ["created_by_id"], name: "index_invoices_on_created_by_id"
    t.index ["invoice_number"], name: "index_invoices_on_invoice_number", unique: true
    t.index ["share_token"], name: "index_invoices_on_share_token", unique: true
    t.index ["status"], name: "index_invoices_on_status"
  end

  create_table "ip_logs", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.datetime "login_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_ip_logs_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "message"
    t.string "notification_type"
    t.boolean "read"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "page_views", force: :cascade do |t|
    t.integer "business_id"
    t.string "path", null: false
    t.string "host", null: false
    t.string "referrer"
    t.string "user_agent"
    t.string "ip_hash"
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "country_code"
    t.string "device_type"
    t.string "browser"
    t.string "os"
    t.string "referrer_domain"
    t.string "event_name"
    t.index ["business_id", "event_name", "occurred_at"], name: "index_page_views_on_business_event_and_time"
    t.index ["business_id", "occurred_at"], name: "index_page_views_on_business_id_and_occurred_at"
    t.index ["business_id"], name: "index_page_views_on_business_id"
    t.index ["country_code"], name: "index_page_views_on_country_code"
    t.index ["device_type"], name: "index_page_views_on_device_type"
    t.index ["event_name"], name: "index_page_views_on_event_name"
    t.index ["occurred_at"], name: "index_page_views_on_occurred_at"
    t.index ["referrer_domain"], name: "index_page_views_on_referrer_domain"
  end

  create_table "payment_ip_logs", force: :cascade do |t|
    t.integer "payment_id", null: false
    t.string "ip_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payment_id"], name: "index_payment_ip_logs_on_payment_id"
  end

  create_table "payments", force: :cascade do |t|
    t.integer "user_id"
    t.integer "product_id"
    t.string "status"
    t.decimal "amount"
    t.string "payment_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "currency"
    t.boolean "initial_payment", default: false
    t.string "payment_method"
    t.integer "booking_id"
    t.index ["booking_id"], name: "index_payments_on_booking_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.integer "business_id"
    t.string "reviewer_name", null: false
    t.string "company_name"
    t.text "review_text", null: false
    t.integer "rating", default: 5, null: false
    t.string "avatar_url"
    t.boolean "active", default: true, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source", default: "google", null: false
    t.index ["active"], name: "index_reviews_on_active"
    t.index ["business_id"], name: "index_reviews_on_business_id"
    t.index ["position"], name: "index_reviews_on_position"
    t.index ["source"], name: "index_reviews_on_source"
  end

  create_table "seo_settings", force: :cascade do |t|
    t.string "page_name"
    t.string "title"
    t.text "description"
    t.string "keywords"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "image_url"
    t.string "author"
    t.string "robots", default: "index, follow"
    t.string "og_type", default: "website"
    t.string "og_url"
    t.string "og_title"
    t.text "og_description"
    t.string "og_image"
    t.string "twitter_card", default: "summary_large_image"
    t.string "twitter_url"
    t.string "twitter_title"
    t.text "twitter_description"
    t.string "twitter_image"
    t.string "favicon_url"
    t.string "apple_touch_icon_url"
    t.string "canonical_url"
    t.text "structured_data"
  end

  create_table "services", force: :cascade do |t|
    t.string "name", null: false
    t.decimal "base_price", precision: 10, scale: 2, null: false
    t.string "category", null: false
    t.text "description"
    t.boolean "active", default: true
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_services_on_active"
    t.index ["category"], name: "index_services_on_category"
    t.index ["position"], name: "index_services_on_position"
  end

  create_table "users", force: :cascade do |t|
    t.string "username", null: false
    t.string "email"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.boolean "receive_email_notifications", default: true
    t.boolean "admin", default: false
    t.string "status", default: "unverified"
    t.string "verification_token"
    t.datetime "verification_sent_at"
    t.datetime "last_active_at"
    t.string "google_secret"
    t.boolean "inactive", default: false
    t.string "first_name"
    t.string "last_name"
    t.string "phone_number"
    t.integer "business_id"
    t.string "admin_role"
    t.index ["admin_role"], name: "index_users_on_admin_role"
    t.index ["business_id"], name: "index_users_on_business_id"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "vehicle_data", force: :cascade do |t|
    t.string "make", null: false
    t.string "model", null: false
    t.text "years"
    t.text "colors"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["make", "model"], name: "index_vehicle_data_on_make_and_model", unique: true
    t.index ["make"], name: "index_vehicle_data_on_make"
  end

  create_table "vehicles", force: :cascade do |t|
    t.string "make"
    t.string "model"
    t.integer "year"
    t.string "color"
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_vehicles_on_user_id"
  end

  create_table "work_cards", force: :cascade do |t|
    t.string "name", null: false
    t.string "domain_url", null: false
    t.string "image_url"
    t.text "description"
    t.boolean "active", default: true, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_work_cards_on_active"
    t.index ["position"], name: "index_work_cards_on_position"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "users"
  add_foreign_key "banned_ips", "users", column: "banned_by_id"
  add_foreign_key "bookings", "users"
  add_foreign_key "contact_messages", "businesses"
  add_foreign_key "invoices", "businesses"
  add_foreign_key "invoices", "users", column: "created_by_id"
  add_foreign_key "ip_logs", "users"
  add_foreign_key "notifications", "users"
  add_foreign_key "page_views", "businesses"
  add_foreign_key "payment_ip_logs", "payments"
  add_foreign_key "reviews", "businesses"
  add_foreign_key "users", "businesses"
  add_foreign_key "vehicles", "users"
end

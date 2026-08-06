class DemoWebsiteSetting < ApplicationRecord
  THEMES = {
    "violet" => { name: "Violet Glow", primary: "#8B5CF6", accent: "#A78BFA", bg: "#09090B" },
    "emerald" => { name: "Emerald Luxe", primary: "#10B981", accent: "#34D399", bg: "#052E2B" },
    "rose" => { name: "Rose Studio", primary: "#E11D48", accent: "#FB7185", bg: "#2B0A12" },
    "ocean" => { name: "Ocean Pro", primary: "#0284C7", accent: "#38BDF8", bg: "#082F49" },
    "amber" => { name: "Amber Build", primary: "#D97706", accent: "#FBBF24", bg: "#2B1A05" },
    "white_black" => { name: "White & Black", primary: "#FFFFFF", accent: "#000000", bg: "#050505" },
    "black_white" => { name: "Black & White", primary: "#000000", accent: "#FFFFFF", bg: "#111111" },
    "neon_cyber" => { name: "Neon Cyber", primary: "#00F5D4", accent: "#F15BB5", bg: "#080B1A" },
    "sunset_fusion" => { name: "Sunset Fusion", primary: "#F97316", accent: "#EC4899", bg: "#1B0E14" },
    "arctic_electric" => { name: "Arctic Electric", primary: "#06B6D4", accent: "#A5F3FC", bg: "#04141A" },
    "blush" => { name: "Blush Pink", primary: "#E8507B", accent: "#F9A8C9", bg: "#1A0A11" },
    "midnight" => { name: "Midnight Navy", primary: "#3B82F6", accent: "#93C5FD", bg: "#020617" },
    "forest" => { name: "Forest", primary: "#16A34A", accent: "#86EFAC", bg: "#022C22" },
    "slate" => { name: "Slate", primary: "#94A3B8", accent: "#CBD5E1", bg: "#0F172A" },
    "crimson" => { name: "Crimson", primary: "#DC2626", accent: "#FCA5A5", bg: "#1C0505" },
    "lavender" => { name: "Lavender", primary: "#A78BFA", accent: "#DDD6FE", bg: "#0C0A1D" },
    "gold" => { name: "Gold", primary: "#CA8A04", accent: "#FDE68A", bg: "#1A1505" },
    "teal" => { name: "Teal", primary: "#14B8A6", accent: "#5EEAD4", bg: "#042F2E" }
  }.freeze

  LAYOUTS = {
    "show" => { name: "JMG Plastering", desc: "Bold & modern, great for trades and agencies" },
    "show2" => { name: "Dawkes Development", desc: "Sleek minimal layout with strong typography" },
    "show3" => { name: "Smart Business", desc: "Creative portfolio with immersive sections" },
    "show4" => { name: "Beauty Clinic", desc: "Elegant & luxurious, perfect for aesthetics" },
    "show5" => { name: "Accountant", desc: "Professional & trustworthy, ideal for finance" },
    "show6" => { name: "Restaurant", desc: "Upscale dining with a moody editorial feel" },
    "show7" => { name: "Fitness", desc: "Bold & powerful, built for gyms and trainers" },
    "show8" => { name: "Real Estate", desc: "Luxury property agency with premium appeal" }
  }.freeze

  IMAGE_SLOTS = {
    "show" => %w[project_1 project_2 project_3 project_4 project_5 project_6],
    "show2" => %w[about_main drone_feature project_1 project_2 project_3 project_4 project_5 project_6],
    "show3" => %w[project_1 project_2 project_3 project_4 project_5 project_6],
    "show4" => %w[hero_visual about_main project_1 project_2 project_3 project_4 project_5 project_6],
    "show5" => %w[hero_visual project_1 project_2 project_3 project_4 project_5 project_6],
    "show6" => %w[hero_visual project_1 project_2 project_3 project_4 project_5 project_6],
    "show7" => %w[about_main project_1 project_2 project_3 project_4 project_5 project_6],
    "show8" => %w[project_1 project_2 project_3 project_4 project_5 project_6]
  }.freeze

  DEFAULT_FEATURE_CARDS = [
    { title: "Fast Delivery", body: "Quick turnaround times without compromising quality." },
    { title: "Quality Assured", body: "Every project undergoes rigorous quality checks." },
    { title: "Best Value", body: "Transparent pricing and excellent value." },
    { title: "Consultancy & Design", body: "Expert planning, consultation, and support." }
  ].freeze

  DEFAULT_PROJECT_CARDS = [
    { title: "Project One", category: "Featured Project", body: "Professional work showcasing quality and detail." },
    { title: "Project Two", category: "Featured Project", body: "Professional work showcasing quality and detail." },
    { title: "Project Three", category: "Featured Project", body: "Professional work showcasing quality and detail." },
    { title: "Project Four", category: "Featured Project", body: "Professional work showcasing quality and detail." },
    { title: "Project Five", category: "Featured Project", body: "Professional work showcasing quality and detail." },
    { title: "Project Six", category: "Featured Project", body: "Professional work showcasing quality and detail." }
  ].freeze

  DEFAULT_TESTIMONIAL_CARDS = [
    { name: "John Doe", role: "Business Owner", quote: "Absolutely outstanding work and communication." },
    { name: "Sarah Miller", role: "Homeowner", quote: "The process was smooth and the result was perfect." },
    { name: "Michael Johnson", role: "Property Manager", quote: "Professional from start to finish." }
  ].freeze

  DEFAULT_FAQ_ITEMS = [
    { question: "How long does a project take?", answer: "Most projects are completed within 2-4 weeks depending on scope." },
    { question: "Do you offer free consultations?", answer: "Yes, we offer free initial consultations." },
    { question: "What areas do you service?", answer: "We serve local and surrounding areas." },
    { question: "What payment methods do you accept?", answer: "Bank transfer, card, and cash are supported." },
    { question: "Do you provide warranties?", answer: "Yes, all work includes a warranty." },
    { question: "How do I get started?", answer: "Send us a message and we will guide you through the next steps." }
  ].freeze

  DEFAULT_STATS = [
    { number: "100%", label: "Satisfaction" },
    { number: "500+", label: "Projects" },
    { number: "24/7", label: "Support" },
    { number: "10+", label: "Years" }
  ].freeze

  DEFAULT_PROCESS_STEPS = [
    { title: "Discovery", body: "We learn your goals and requirements." },
    { title: "Design", body: "We craft a clear visual direction." },
    { title: "Build", body: "We deliver a polished, high-quality result." },
    { title: "Launch", body: "We deploy and support your launch." }
  ].freeze

  validates :site_title, :hero_heading, :hero_subheading, :theme_name, :layout_name, presence: true
  validates :theme_name, inclusion: { in: THEMES.keys }
  validates :layout_name, inclusion: { in: LAYOUTS.keys }

  def theme
    THEMES.fetch(theme_name, THEMES["violet"])
  end

  def layout_template
    LAYOUTS.key?(layout_name) ? layout_name : "show"
  end

  def feature_cards
    parse_rows(feature_cards_data, keys: [:title, :body], defaults: DEFAULT_FEATURE_CARDS)
  end

  def project_cards
    parse_rows(project_cards_data, keys: [:title, :category, :body], defaults: DEFAULT_PROJECT_CARDS)
  end

  def testimonial_cards
    parse_rows(testimonial_cards_data, keys: [:name, :role, :quote], defaults: DEFAULT_TESTIMONIAL_CARDS)
  end

  def faq_items
    parse_rows(faq_items_data, keys: [:question, :answer], defaults: DEFAULT_FAQ_ITEMS)
  end

  def stat_items
    parse_rows(stat_items_data, keys: [:number, :label], defaults: DEFAULT_STATS)
  end

  def process_steps
    parse_rows(process_steps_data, keys: [:title, :body], defaults: DEFAULT_PROCESS_STEPS)
  end

  def image_slots
    IMAGE_SLOTS.fetch(layout_template, IMAGE_SLOTS["show"])
  end

  def image_map
    image_slots_data.to_s.lines.each_with_object({}) do |line, acc|
      slot, url = line.to_s.split("|", 2).map { |part| part.to_s.strip }
      next if slot.blank? || url.blank?

      acc[slot] = url
    end
  end

  def image_for(slot, fallback = nil)
    image_map[slot.to_s].presence || fallback
  end

  private

  def parse_rows(raw, keys:, defaults:)
    rows = raw.to_s.lines.map(&:strip).reject(&:blank?).each_with_index.map do |line, row_index|
      parts = line.split("|", keys.length).map { |part| part.to_s.strip }
      next if parts.all?(&:blank?)

      keys.each_with_index.with_object({}) do |(key, idx), item|
        item[key] = parts[idx].presence || defaults[row_index % defaults.length][key]
      end
    end.compact

    rows = defaults if rows.empty?
    rows.first(defaults.length)
  end
end

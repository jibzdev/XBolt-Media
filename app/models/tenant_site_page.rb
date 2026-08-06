class TenantSitePage < ApplicationRecord
  DEFAULT_SECTIONS = [
    {
      "type" => "hero",
      "heading" => "Your business, beautifully presented",
      "body" => "Use the website builder to update this page from your dashboard.",
      "button_text" => "Get in touch",
      "button_url" => "/contact"
    },
    {
      "type" => "text",
      "heading" => "About us",
      "body" => "Tell customers what you do, who you help, and why they should choose you."
    },
    {
      "type" => "contact_form",
      "heading" => "Contact us",
      "body" => "Send us a message and we will get back to you soon."
    }
  ].freeze

  ALLOWED_BLOCK_TYPES = %w[
    hero
    text
    image
    split
    gallery
    cards
    testimonials
    cta
    contact_form
    faq
  ].freeze

  SECTION_TEMPLATES = {
    "hero" => {
      "type" => "hero",
      "eyebrow" => "Welcome",
      "heading" => "New hero section",
      "body" => "Introduce your business with a clear headline and short supporting text.",
      "button_text" => "Get in touch",
      "button_url" => "/contact"
    },
    "text" => {
      "type" => "text",
      "heading" => "New text section",
      "body" => "Add the details your customers need to know."
    },
    "image" => {
      "type" => "image",
      "heading" => "Featured image",
      "body" => "Choose an image from your media library.",
      "image_alt" => "Featured image"
    },
    "split" => {
      "type" => "split",
      "heading" => "Split feature",
      "body" => "Pair a short story with a supporting image.",
      "button_text" => "Learn more",
      "button_url" => "/",
      "image_alt" => "Feature image"
    },
    "gallery" => {
      "type" => "gallery",
      "heading" => "Gallery",
      "body" => "Showcase work from your media library.",
      "category" => "general"
    },
    "cards" => {
      "type" => "cards",
      "heading" => "What we offer",
      "body" => "Highlight your services or features.",
      "items" => [
        { "title" => "Service one", "subtitle" => "Popular", "body" => "Describe this offer." },
        { "title" => "Service two", "subtitle" => "", "body" => "Describe this offer." }
      ]
    },
    "testimonials" => {
      "type" => "testimonials",
      "heading" => "What customers say",
      "body" => "Share recent feedback.",
      "items" => [
        { "quote" => "Fantastic experience from start to finish.", "name" => "Alex", "role" => "Customer" }
      ]
    },
    "cta" => {
      "type" => "cta",
      "heading" => "Ready to get started?",
      "body" => "Invite visitors to take the next step.",
      "button_text" => "Contact us",
      "button_url" => "/contact"
    },
    "contact_form" => {
      "type" => "contact_form",
      "heading" => "Contact us",
      "body" => "Send a message and we will get back to you soon."
    },
    "faq" => {
      "type" => "faq",
      "heading" => "Frequently asked questions",
      "body" => "Answer the questions people ask most.",
      "faqs" => [
        { "question" => "How does this work?", "answer" => "Add a clear, helpful answer here." }
      ]
    }
  }.freeze

  belongs_to :business

  before_validation :normalize_slug
  before_validation :ensure_sections

  validates :title, presence: true, length: { maximum: 120 }
  validates :slug, presence: true, uniqueness: { scope: :business_id }, length: { maximum: 120 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :sections_are_allowed

  scope :ordered, -> { order(position: :asc, id: :asc) }

  def self.template_for(type)
    SECTION_TEMPLATES[type.to_s]&.deep_dup
  end

  def home?
    slug == "/"
  end

  def output_path
    return "index.html" if home?

    "#{slug.delete_prefix('/')}/index.html"
  end

  private

  def normalize_slug
    raw = slug.to_s.strip.downcase
    raw = "/" if raw.blank? || raw == "home" || raw == "index"
    raw = "/#{raw}" unless raw.start_with?("/")
    raw = raw.gsub(%r{/+}, "/")
    raw = raw.gsub(/[^a-z0-9\/\-]/, "-").gsub(/-+/, "-")
    raw = raw.delete_suffix("/") unless raw == "/"
    self.slug = raw.presence || "/"
  end

  def ensure_sections
    self.sections = DEFAULT_SECTIONS.deep_dup if sections.blank?
  end

  def sections_are_allowed
    unless sections.is_a?(Array)
      errors.add(:sections, "must be a list of blocks")
      return
    end

    sections.each_with_index do |section, index|
      unless section.is_a?(Hash)
        errors.add(:sections, "block #{index + 1} is invalid")
        next
      end

      type = section["type"].to_s
      errors.add(:sections, "block #{index + 1} has an unsupported type") unless ALLOWED_BLOCK_TYPES.include?(type)
    end
  end
end

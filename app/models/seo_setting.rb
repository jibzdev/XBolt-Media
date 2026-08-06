class SeoSetting < ApplicationRecord
  validates :page_name, presence: true, uniqueness: true
  validates :title, presence: true, length: { maximum: 60 }
  validates :description, presence: true, length: { maximum: 160 }
  validates :keywords, presence: true, length: { maximum: 255 }
  
  # Scopes
  scope :for_page, ->(page_name) { where(page_name: page_name).first }
  
  # Helper methods
  def meta_tags
    {
      title: title,
      description: description,
      keywords: keywords,
      author: author,
      robots: robots,
      og_type: og_type,
      og_url: og_url,
      og_title: og_title || title,
      og_description: og_description || description,
      og_image: og_image,
      twitter_card: twitter_card,
      twitter_url: twitter_url,
      twitter_title: twitter_title || title,
      twitter_description: twitter_description || description,
      twitter_image: twitter_image,
      favicon_url: favicon_url,
      apple_touch_icon_url: apple_touch_icon_url,
      canonical_url: canonical_url
    }
  end
  
  def self.default_pages
    %w[landing reviews login terms_of_service privacy_policy]
  end
  
  def self.initialize_defaults
    default_pages.each do |page|
      unless exists?(page_name: page)
        create!(
          page_name: page,
          title: default_title_for(page),
          description: default_description_for(page),
          keywords: default_keywords_for(page),
          author: 'XBolt',
          robots: 'index, follow',
          og_type: 'website',
          og_url: "https://xboltmedia.com/#{page == 'landing' ? '' : page}",
          og_title: default_title_for(page),
          og_description: default_description_for(page),
          og_image: 'https://xboltmedia.com/assets/images/logo4.png',
          twitter_card: 'summary_large_image',
          twitter_url: "https://xboltmedia.com/#{page == 'landing' ? '' : page}",
          twitter_title: default_title_for(page),
          twitter_description: default_description_for(page),
          twitter_image: 'https://xboltmedia.com/assets/images/logo4.png',
          favicon_url: 'https://xboltmedia.com/assets/images/logo3.png',
          apple_touch_icon_url: 'https://xboltmedia.com/assets/images/logo3.png',
          canonical_url: "https://xboltmedia.com/#{page == 'landing' ? '' : page}"
        )
      end
    end
  end
  
  private
  
  def self.default_title_for(page)
    case page
    when 'landing'
      'XBolt - Digital Studio'
    when 'reviews'
      'Client Reviews - XBolt'
    when 'login'
      'Login - XBolt'
    when 'terms_of_service'
      'Terms of Service - XBolt'
    when 'privacy_policy'
      'Privacy Policy - XBolt'
    else
      'XBolt'
    end
  end
  
  def self.default_description_for(page)
    case page
    when 'landing'
      'XBolt builds fast, modern websites and digital experiences. Design, development, and ongoing support.'
    when 'reviews'
      'Read verified Google reviews from XBolt Media clients. See what founders and business owners say about working with us.'
    when 'login'
      'Sign in to access the XBolt dashboard.'
    when 'terms_of_service'
      'Terms and conditions for using XBolt services.'
    when 'privacy_policy'
      'Privacy policy for XBolt. Learn how we protect and handle your personal information and data.'
    else
      'XBolt - Digital Studio'
    end
  end
  
  def self.default_keywords_for(page)
    case page
    when 'landing'
      'web design, web development, branding, digital studio, SEO, performance, hosting'
    when 'reviews'
      'XBolt reviews, client testimonials, Google reviews, web design reviews'
    when 'login'
      'login, dashboard access, XBolt'
    when 'terms_of_service'
      'terms, conditions, service agreement, XBolt, policies'
    when 'privacy_policy'
      'privacy, data protection, personal information, XBolt'
    else
      'XBolt, web development, digital'
    end
  end
end

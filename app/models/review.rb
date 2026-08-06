class Review < ApplicationRecord
  SOURCES = %w[google direct].freeze

  belongs_to :business, optional: true

  validates :reviewer_name, presence: true
  validates :review_text, presence: true
  validates :rating, inclusion: { in: 1..5 }
  validates :source, inclusion: { in: SOURCES }

  scope :visible, -> { where(active: true).order(position: :asc, created_at: :desc) }

  def self.average_rating
    average(:rating)&.round(1)
  end

  def google?
    source == "google"
  end

  def display_avatar_url
    return avatar_url if avatar_url.present?
    return business.image_url if business&.image_url.present?

    nil
  end

  def display_company
    return company_name if company_name.present?

    business&.name
  end

  def initials
    reviewer_name.to_s.split.map(&:first).first(2).join.upcase
  end
end

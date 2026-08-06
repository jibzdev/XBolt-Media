class WorkCard < ApplicationRecord
  before_validation :normalize_domain_url

  validates :name, presence: true
  validates :domain_url, presence: true, length: { maximum: 2048 }, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :image_url, length: { maximum: 2048 }, allow_blank: true
  validates :description, length: { maximum: 2000 }, allow_blank: true

  scope :visible, -> { where(active: true).order(position: :asc, created_at: :desc) }
  scope :ordered, -> { order(position: :asc, created_at: :desc) }

  private

  def normalize_domain_url
    raw = domain_url.to_s.strip
    return if raw.blank?

    self.domain_url = raw.match?(%r{\Ahttps?://}i) ? raw : "https://#{raw}"
  end
end

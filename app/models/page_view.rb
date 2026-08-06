class PageView < ApplicationRecord
  belongs_to :business, optional: true

  validates :path, :host, :occurred_at, presence: true

  scope :page_hits, -> { where(event_name: [nil, 'page_view']) }
  scope :events, -> { where.not(event_name: [nil, 'page_view']) }
  scope :event, ->(name) { where(event_name: name.to_s) }
  scope :recent, -> { order(occurred_at: :desc) }
  scope :last_24_hours, -> { where('occurred_at > ?', 24.hours.ago) }
  scope :last_7_days, -> { where('occurred_at > ?', 7.days.ago) }
  scope :last_30_days, -> { where('occurred_at > ?', 30.days.ago) }
  scope :previous_24_hours, -> { where(occurred_at: 48.hours.ago..24.hours.ago) }
  scope :previous_7_days, -> { where(occurred_at: 14.days.ago..7.days.ago) }
  scope :previous_30_days, -> { where(occurred_at: 60.days.ago..30.days.ago) }

  def self.unique_visitors
    distinct.count(:ip_hash)
  end

  def self.views_by_day(days: 7)
    cutoff = days.days.ago.beginning_of_day
    where('occurred_at > ?', cutoff)
      .pluck(:occurred_at)
      .group_by { |t| t.to_date }
      .transform_values(&:size)
  end

  def self.views_by_hour(hours: 24)
    cutoff = hours.hours.ago
    raw = where('occurred_at > ?', cutoff).pluck(:occurred_at)
    grouped = raw.group_by { |t| t.beginning_of_hour }.transform_values(&:size)
    hours.times { |i| grouped[i.hours.ago.beginning_of_hour] ||= 0 }
    grouped.sort.to_h
  end

  def self.top_breakdown(column, limit: 8)
    group(column).order(Arel.sql('count_all DESC')).limit(limit).count
  end
end

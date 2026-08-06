class Invoice < ApplicationRecord
  belongs_to :business
  belongs_to :created_by, class_name: 'User', optional: true

  STATUSES = %w[draft sent paid overdue].freeze
  BILLING_TYPES = %w[one_time monthly].freeze
  MAX_LINE_ITEMS = 100

  before_validation :assign_invoice_number, on: :create
  before_validation :assign_share_token, on: :create
  before_validation :normalize_line_items
  before_validation :compute_totals

  validates :invoice_number, presence: true, uniqueness: true
  validates :share_token, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :issue_date, :due_date, presence: true
  validates :notes, length: { maximum: 5000 }, allow_blank: true
  validate :line_items_present
  validate :line_items_size_within_limit
  validate :due_date_on_or_after_issue_date

  scope :recent, -> { order(created_at: :desc) }

  def status_badge_classes
    case status
    when 'paid' then 'bg-emerald-50 text-emerald-700 border-emerald-200'
    when 'sent' then 'bg-blue-50 text-blue-700 border-blue-200'
    when 'overdue' then 'bg-red-50 text-red-700 border-red-200'
    else 'bg-zinc-100 text-zinc-700 border-zinc-200'
    end
  end

  def grouped_line_items
    items = line_items.is_a?(Array) ? line_items : []
    {
      'one_time' => items.select { |item| item['billing_type'] == 'one_time' },
      'monthly' => items.select { |item| item['billing_type'] == 'monthly' }
    }
  end

  private

  def assign_invoice_number
    return if invoice_number.present?

    date_prefix = Time.current.strftime('%Y%m')
    loop do
      candidate = "INV-#{date_prefix}-#{SecureRandom.random_number(10_000).to_s.rjust(4, '0')}"
      unless self.class.exists?(invoice_number: candidate)
        self.invoice_number = candidate
        break
      end
    end
  end

  def assign_share_token
    return if share_token.present?

    loop do
      token = SecureRandom.hex(16)
      unless self.class.exists?(share_token: token)
        self.share_token = token
        break
      end
    end
  end

  def normalize_line_items
    raw_items = line_items.is_a?(Array) ? line_items : []
    self.line_items = raw_items.filter_map do |item|
      item = item.to_h if item.respond_to?(:to_h)
      next unless item.is_a?(Hash)

      description = item['description'].to_s.strip.presence || item[:description].to_s.strip.presence
      quantity_raw = item['quantity'].presence || item[:quantity].presence
      unit_price_raw = item['unit_price'].presence || item[:unit_price].presence
      billing_type_raw = item['billing_type'].presence || item[:billing_type].presence
      quantity = quantity_raw.to_f
      unit_price = unit_price_raw.to_f
      billing_type = billing_type_raw.to_s
      billing_type = 'one_time' unless BILLING_TYPES.include?(billing_type)
      next if description.blank?
      next if description.length > 200
      next if quantity <= 0
      next if quantity > 100_000
      next if unit_price < 0
      next if unit_price > 1_000_000

      {
        'description' => description,
        'quantity' => quantity.round(2),
        'unit_price' => unit_price.round(2),
        'billing_type' => billing_type
      }
    end
  end

  def compute_totals
    calculated_subtotal = line_items.sum { |item| item['quantity'].to_f * item['unit_price'].to_f }
    self.subtotal = calculated_subtotal.round(2)
    self.total = subtotal
  end

  def line_items_present
    return if line_items.is_a?(Array) && line_items.any?

    errors.add(:line_items, 'must include at least one valid invoice item')
  end

  def line_items_size_within_limit
    return unless line_items.is_a?(Array) && line_items.size > MAX_LINE_ITEMS

    errors.add(:line_items, "cannot exceed #{MAX_LINE_ITEMS} items")
  end

  def due_date_on_or_after_issue_date
    return if issue_date.blank? || due_date.blank?
    return if due_date >= issue_date

    errors.add(:due_date, 'must be on or after the issue date')
  end
end

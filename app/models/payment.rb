# Legacy payment ledger model kept for the upcoming payment integration.
# Prefer provider-hosted checkout + signed webhooks; never store raw card data.
class Payment < ApplicationRecord
  belongs_to :user
  has_many :payment_ip_logs, dependent: :destroy

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :payment_type, presence: true

  enum status: {
    pending: "pending",
    successful: "successful",
    cancelled: "cancelled",
    voided: "voided",
    refunded: "refunded"
  }

  enum payment_type: {
    deposit: "deposit",
    full_payment: "full_payment",
    partial_payment: "partial_payment",
    refund: "refund"
  }

  enum payment_method: {
    card: "card",
    cash: "cash"
  }

  scope :successful, -> { where(status: "successful") }
  scope :pending, -> { where(status: "pending") }
  scope :recent, -> { order(created_at: :desc) }

  def formatted_amount
    format("£%.2f", amount.to_f)
  end

  def formatted_date
    created_at.strftime("%B %d, %Y at %I:%M %p")
  end

  def refundable?
    successful? && !refunded?
  end
end

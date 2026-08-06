class Service < ApplicationRecord
  validates :name, presence: true
  validates :base_price, presence: true, numericality: { greater_than: 0 }
  validates :category, presence: true
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }
  
  # Helper methods
  def formatted_price
    "£#{number_with_precision(base_price, precision: 2)}"
  end
  
  def display_name
    "#{name} - #{formatted_price}"
  end
end

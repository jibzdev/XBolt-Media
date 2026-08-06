class VehicleData < ApplicationRecord
  validates :make, presence: true
  validates :model, presence: true
  validates :make, uniqueness: { scope: :model }

  serialize :years, Array
  serialize :colors, Array

  scope :by_make, ->(make) { where(make: make) }
  scope :ordered, -> { order(:make, :model) }

  def self.popular_makes
    distinct.pluck(:make).compact.sort
  end

  def self.models_for_make(make)
    by_make(make).distinct.pluck(:model).compact.sort
  end

  def self.years_for_make_model(make, model)
    find_by(make: make, model: model)&.years || []
  end

  def self.colors_for_make_model(make, model)
    find_by(make: make, model: model)&.colors || []
  end
end

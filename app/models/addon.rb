# == Schema Information
#
# Table name: addons
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  description          :string           not null
#  discount             :decimal(10, 2)   default(0.0)
#  discount_description :string
#  quantity             :integer          default(1)
#  total_price          :decimal(10, 2)
#  unit_price           :decimal(10, 2)
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  line_item_id         :uuid             not null
#
# Indexes
#
#  index_addons_on_line_item_id  (line_item_id)
#
# Foreign Keys
#
#  fk_rails_...  (line_item_id => line_items.id)
#
class Addon < ApplicationRecord
  include HasWarnings

  # Associations
  belongs_to :line_item

  # Validations
  validates :description, presence: true
  validates :unit_price, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :quantity, presence: true, numericality: {greater_than_or_equal_to: 1}
  validates :discount, numericality: {greater_than_or_equal_to: 0}, allow_nil: true

  # Callbacks
  before_validation :set_defaults
  before_save :calculate_total

  # Instance methods
  def base_total
    (unit_price * quantity) - discount
  end

  private

  def set_defaults
    self.quantity ||= 1
    self.discount ||= 0
  end

  def calculate_total
    self.total_price = base_total
  end

  def run_warning_checks
    # Warn about zero quantity
    if quantity && quantity == 0
      add_warning(:quantity, "is zero. Addons with no quantity should typically be removed.")
    end

    # Warn about unusually high price for an addon
    if unit_price && unit_price > 100
      add_warning(:unit_price, "seems high for an addon (#{unit_price}). Please verify this is correct.")
    end

    # Warn if discount exceeds price
    if discount && unit_price && discount > unit_price
      add_warning(:discount, "exceeds the addon price. Please verify this is correct.")
    end
  end
end

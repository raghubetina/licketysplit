# == Schema Information
#
# Table name: addons
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  addon_total          :decimal(10, 2)
#  description          :string           not null
#  discount             :decimal(10, 2)   default(0.0)
#  discount_description :string
#  price                :decimal(10, 2)   not null
#  price_per            :decimal(10, 2)
#  quantity             :integer          default(1)
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
  # Associations
  belongs_to :line_item

  # Validations
  validates :description, presence: true
  validates :price, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :quantity, presence: true, numericality: {greater_than: 0}
  validates :discount, numericality: {greater_than_or_equal_to: 0}

  # Callbacks
  before_validation :set_defaults
  before_save :calculate_total

  # Instance methods
  def base_total
    if price_per.present?
      (price_per * quantity) - discount
    else
      price - discount
    end
  end

  private

  def set_defaults
    self.quantity ||= 1
    self.discount ||= 0
  end

  def calculate_total
    self.addon_total = base_total
  end
end

# == Schema Information
#
# Table name: discounts
# Database name: primary
#
#  id          :uuid             not null, primary key
#  amount      :decimal(10, 2)   not null
#  description :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  check_id    :uuid             not null
#
# Indexes
#
#  index_discounts_on_check_id  (check_id)
#
# Foreign Keys
#
#  fk_rails_...  (check_id => checks.id)
#
class Discount < ApplicationRecord
  # Associations
  belongs_to :check

  # Validations
  validates :amount, presence: true, numericality: {greater_than: 0}
  validates :description, presence: true

  # Scopes
  scope :promotional, -> { where("description ILIKE ?", "%promo%") }
  scope :coupon, -> { where("description ILIKE ?", "%coupon%") }

  # Instance methods
  def is_percentage?
    description.include?("%")
  end

  def percentage_value
    return nil unless is_percentage?
    description.scan(/(\d+(?:\.\d+)?)\s*%/).flatten.first&.to_f
  end
end

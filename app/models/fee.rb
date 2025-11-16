# == Schema Information
#
# Table name: fees
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
#  index_fees_on_check_id  (check_id)
#
# Foreign Keys
#
#  fk_rails_...  (check_id => checks.id)
#
class Fee < ApplicationRecord
  # Associations
  belongs_to :check

  # Validations
  validates :amount, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :description, presence: true

  # Scopes
  scope :taxes, -> { where("description ILIKE ?", "%tax%") }
  scope :tips, -> { where("description ILIKE ?", "%tip%") }
  scope :service_charges, -> { where("description ILIKE ?", "%service%") }

  # Instance methods
  def is_tip?
    description.downcase.include?("tip")
  end

  def is_tax?
    description.downcase.include?("tax")
  end

  def is_service_charge?
    description.downcase.include?("service")
  end
end

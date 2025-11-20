# == Schema Information
#
# Table name: global_discounts
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
#  index_global_discounts_on_check_id  (check_id)
#
# Foreign Keys
#
#  fk_rails_...  (check_id => checks.id)
#
class GlobalDiscount < ApplicationRecord
  belongs_to :check

  validates :amount, presence: true, numericality: {greater_than: 0}
  validates :description, presence: true
end

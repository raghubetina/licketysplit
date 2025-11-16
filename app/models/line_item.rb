# == Schema Information
#
# Table name: line_items
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  description          :text
#  discount             :decimal(10, 2)   default(0.0)
#  discount_description :string
#  line_item_total      :decimal(10, 2)
#  name                 :string           not null
#  price                :decimal(10, 2)   not null
#  quantity             :integer          default(1)
#  shared_by_count      :integer          default(1)
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  check_id             :uuid             not null
#
# Indexes
#
#  index_line_items_on_check_id  (check_id)
#
# Foreign Keys
#
#  fk_rails_...  (check_id => checks.id)
#
class LineItem < ApplicationRecord
  # Associations
  belongs_to :check
  has_many :line_item_participants, dependent: :destroy
  has_many :participants, through: :line_item_participants
  has_many :addons, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :price, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :quantity, presence: true, numericality: {greater_than: 0}
  validates :discount, numericality: {greater_than_or_equal_to: 0}
  validates :shared_by_count, numericality: {greater_than: 0}

  # Callbacks
  before_validation :set_defaults
  before_save :calculate_total

  # Instance methods
  def base_total
    (price * quantity) - discount
  end

  def addon_total
    addons.sum(:addon_total)
  end

  def total_with_addons
    base_total + addon_total
  end

  def amount_per_participant
    return 0 if participants.empty?

    # If shared_by_count is set, use that for splitting
    divisor = (shared_by_count > 1) ? shared_by_count : participants.count
    total_with_addons / divisor
  end

  def participant_count
    participants.count
  end

  private

  def set_defaults
    self.quantity ||= 1
    self.discount ||= 0
    self.shared_by_count ||= 1
  end

  def calculate_total
    self.line_item_total = base_total
  end
end

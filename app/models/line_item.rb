# == Schema Information
#
# Table name: line_items
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  description          :text             not null
#  discount             :decimal(10, 2)   default(0.0)
#  discount_description :string
#  participants_count   :integer          default(0)
#  position             :integer          default(0)
#  quantity             :integer          default(1)
#  total_price          :decimal(10, 2)
#  unit_price           :decimal(10, 2)   not null
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
  include HasWarnings

  belongs_to :check, counter_cache: true
  has_many :line_item_participants, dependent: :destroy
  has_many :participants, through: :line_item_participants
  has_many :addons, dependent: :destroy

  validates :description, presence: true
  validates :unit_price, presence: true, numericality: true
  validates :quantity, presence: true, numericality: {greater_than_or_equal_to: 1}
  validates :discount, numericality: {greater_than_or_equal_to: 0}, allow_nil: true

  accepts_nested_attributes_for :addons, allow_destroy: true

  before_validation :set_defaults
  before_save :calculate_total
  after_commit :broadcast_updates

  def base_total
    (unit_price * quantity) - discount
  end

  def addons_total
    addons.sum(:total_price)
  end

  def total_with_addons
    base_total + addons_total
  end

  def amount_per_participant
    return 0 if participants_count == 0
    total_with_addons / participants_count
  end

  private

  def broadcast_updates
    if destroyed?
      broadcast_remove_to(check, target: ActionView::RecordIdentifier.dom_id(self))
    elsif previously_new_record?
      broadcast_before_to(
        check,
        target: "new_line_item_form",
        partial: "line_items/line_item",
        locals: {line_item: self, check: check}
      )
    else
      broadcast_replace_to(
        check,
        target: ActionView::RecordIdentifier.dom_id(self),
        partial: "line_items/line_item",
        locals: {line_item: self, check: check}
      )
    end

    participants.each do |participant|
      broadcast_replace_to(
        check,
        target: ActionView::RecordIdentifier.dom_id(participant, :breakdown),
        partial: "checks/participant_breakdown",
        locals: {participant: participant, check: check}
      )
    end

    broadcast_replace_to(
      check,
      target: "remaining_breakdown",
      partial: "checks/remaining_breakdown",
      locals: {check: check}
    )
  end

  def set_defaults
    self.quantity ||= 1
    self.discount ||= 0
  end

  def calculate_total
    self.total_price = base_total
  end

  def run_warning_checks
    if unit_price && unit_price < 0
      add_warning(:unit_price, "is negative (#{unit_price}). This might be a comped item that should be recorded as a discount instead.")
    end

    if discount && unit_price && discount > unit_price
      add_warning(:discount, "exceeds the item price. Please verify this is correct.")
    end

    if unit_price && unit_price > 1000
      add_warning(:unit_price, "seems unusually high (#{unit_price}). Please verify this is correct.")
    end
  end
end

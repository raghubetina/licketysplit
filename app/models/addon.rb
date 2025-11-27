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

  belongs_to :line_item

  validates :description, presence: true
  validates :unit_price, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :quantity, presence: true, numericality: {greater_than_or_equal_to: 1}
  validates :discount, numericality: {greater_than_or_equal_to: 0}, allow_nil: true

  before_validation :set_defaults
  before_save :calculate_total
  after_commit :broadcast_updates

  def base_total
    (unit_price * quantity) - discount
  end

  private

  def broadcast_updates
    check = line_item.check

    if destroyed?
      broadcast_remove_to(check, target: ActionView::RecordIdentifier.dom_id(self))
    else
      broadcast_replace_to(
        check,
        target: ActionView::RecordIdentifier.dom_id(self),
        partial: "addons/addon",
        locals: {addon: self, line_item: line_item}
      )
    end

    broadcast_replace_to(
      check,
      target: ActionView::RecordIdentifier.dom_id(line_item),
      partial: "line_items/line_item",
      locals: {line_item: line_item, check: check}
    )

    line_item.participants.each do |participant|
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
    if unit_price && unit_price > 100
      add_warning(:unit_price, "seems high for an addon (#{unit_price}). Please verify this is correct.")
    end

    if discount && unit_price && discount > unit_price
      add_warning(:discount, "exceeds the addon price. Please verify this is correct.")
    end
  end
end

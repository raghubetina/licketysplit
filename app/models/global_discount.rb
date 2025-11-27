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

  after_commit :broadcast_updates

  private

  def broadcast_updates
    return if check.parsing?

    check.reload

    if destroyed?
      broadcast_remove_to(check, target: ActionView::RecordIdentifier.dom_id(self))
    elsif previously_new_record?
      broadcast_before_to(
        check,
        target: "new_global_discount_form",
        partial: "global_discounts/global_discount",
        locals: {global_discount: self, check: check}
      )
    else
      broadcast_replace_to(
        check,
        target: ActionView::RecordIdentifier.dom_id(self),
        partial: "global_discounts/global_discount",
        locals: {global_discount: self, check: check}
      )
    end

    check.participants.each do |participant|
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

    broadcast_replace_to(
      check,
      target: "after_discounts_total",
      partial: "checks/after_discounts_total",
      locals: {check: check}
    )

    broadcast_replace_to(
      check,
      target: "grand_total",
      partial: "checks/grand_total",
      locals: {check: check}
    )

    broadcast_replace_to(
      check,
      target: "header_stats",
      partial: "checks/header_stats",
      locals: {check: check}
    )
  end
end

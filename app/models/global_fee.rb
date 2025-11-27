# == Schema Information
#
# Table name: global_fees
# Database name: primary
#
#  id          :uuid             not null, primary key
#  amount      :decimal(10, 2)   not null
#  description :string           not null
#  fee_type    :string           default("other"), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  check_id    :uuid             not null
#
# Indexes
#
#  index_global_fees_on_check_id  (check_id)
#  index_global_fees_on_fee_type  (fee_type)
#
# Foreign Keys
#
#  fk_rails_...  (check_id => checks.id)
#
class GlobalFee < ApplicationRecord
  belongs_to :check

  enum :fee_type, {tip: "tip", tax: "tax", other: "other"}

  validates :amount, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :description, presence: true

  before_save :replace_existing_tip, if: :tip?
  after_commit :broadcast_updates

  def percentage_base
    if tip?
      check.subtotal
    else
      check.subtotal - check.total_discounts
    end
  end

  def calculated_percentage
    base = percentage_base
    return 0 if base <= 0
    (amount / base) * 100
  end

  private

  def replace_existing_tip
    check.global_fees.tip.where.not(id: id).destroy_all
  end

  def broadcast_updates
    check.reload if destroyed?

    if destroyed?
      broadcast_remove_to(check, target: ActionView::RecordIdentifier.dom_id(self))
    elsif previously_new_record?
      broadcast_before_to(
        check,
        target: "new_global_fee_form",
        partial: "global_fees/global_fee",
        locals: {global_fee: self, check: check}
      )
    else
      broadcast_replace_to(
        check,
        target: ActionView::RecordIdentifier.dom_id(self),
        partial: "global_fees/global_fee",
        locals: {global_fee: self, check: check}
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
      target: "grand_total",
      partial: "checks/grand_total",
      locals: {check: check}
    )
  end
end

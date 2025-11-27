# == Schema Information
#
# Table name: global_fees
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
#  index_global_fees_on_check_id  (check_id)
#
# Foreign Keys
#
#  fk_rails_...  (check_id => checks.id)
#
class GlobalFee < ApplicationRecord
  belongs_to :check

  validates :amount, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :description, presence: true

  after_commit :broadcast_updates

  private

  def broadcast_updates
    check.reload if destroyed?

    if destroyed?
      broadcast_remove_to(check, target: ActionView::RecordIdentifier.dom_id(self))
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

# == Schema Information
#
# Table name: participants
# Database name: primary
#
#  id             :uuid             not null, primary key
#  name           :string           not null
#  payment_status :string           default("unpaid")
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  check_id       :uuid             not null
#
# Indexes
#
#  index_participants_on_check_id           (check_id)
#  index_participants_on_check_id_and_name  (check_id,name) UNIQUE
#  index_participants_on_payment_status     (payment_status)
#
# Foreign Keys
#
#  fk_rails_...  (check_id => checks.id)
#
class Participant < ApplicationRecord
  belongs_to :check, counter_cache: true
  has_many :line_item_participants, dependent: :destroy
  has_many :line_items, through: :line_item_participants
  has_one :treat, dependent: :destroy

  validates :name, presence: true
  validates :name, uniqueness: {scope: :check_id, message: "already exists for this check"}

  enum :payment_status, {unpaid: "unpaid", paid: "paid"}

  after_commit :broadcast_updates

  scope :treated, -> { joins(:treat) }
  scope :not_treated, -> { where.missing(:treat) }

  def amount_owed
    check.amount_owed_by(self)
  end

  def is_being_treated?
    treat.present?
  end

  def mark_as_paid!
    update!(payment_status: "paid")
  end

  def mark_as_unpaid!
    update!(payment_status: "unpaid")
  end

  private

  def broadcast_updates
    check.reload if destroyed?

    if destroyed?
      broadcast_remove_to(check, target: ActionView::RecordIdentifier.dom_id(self))
      broadcast_remove_to(check, target: ActionView::RecordIdentifier.dom_id(self, :breakdown))
    elsif previously_new_record?
      broadcast_before_to(
        check,
        target: "new_participant_form",
        partial: "participants/participant",
        locals: {participant: self, check: check}
      )
      broadcast_append_to(
        check,
        target: "participant_breakdowns",
        partial: "checks/participant_breakdown",
        locals: {participant: self, check: check}
      )
    else
      broadcast_replace_to(
        check,
        target: ActionView::RecordIdentifier.dom_id(self),
        partial: "participants/participant",
        locals: {participant: self, check: check}
      )
    end

    # Update all line items to refresh participant checkboxes
    check.line_items.each do |line_item|
      broadcast_replace_to(
        check,
        target: ActionView::RecordIdentifier.dom_id(line_item),
        partial: "line_items/line_item",
        locals: {line_item: line_item, check: check, participants: check.participants.order(:name)}
      )
    end

    # Update breakdown for remaining participants
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
      target: "header_stats",
      partial: "checks/header_stats",
      locals: {check: check}
    )
  end
end

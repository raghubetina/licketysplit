# == Schema Information
#
# Table name: checks
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  currency                :string           default("USD")
#  receipt_at              :datetime
#  receipt_image           :string
#  restaurant_address      :string
#  restaurant_name         :string
#  restaurant_phone_number :string
#  status                  :string           default("draft")
#  total                   :decimal(10, 2)
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
# Indexes
#
#  index_checks_on_status  (status)
#
class Check < ApplicationRecord
  # Associations
  has_many :participants, dependent: :destroy
  has_many :line_items, dependent: :destroy
  has_many :fees, dependent: :destroy
  has_many :discounts, dependent: :destroy
  has_many :treats, dependent: :destroy
  has_many :treated_participants, through: :treats, source: :participant

  # Validations
  validates :status, inclusion: {in: %w[draft reviewing finalized]}
  validates :currency, presence: true

  # Enums
  enum :status, {draft: "draft", reviewing: "reviewing", finalized: "finalized"}

  # Callbacks
  before_validation :set_defaults

  # Instance methods
  def subtotal
    line_items.sum { |item| item.total_with_addons }
  end

  def total_fees
    fees.sum(:amount)
  end

  def total_discounts
    discounts.sum(:amount)
  end

  def calculated_total
    subtotal + total_fees - total_discounts
  end

  def amount_owed_by(participant)
    return 0.0 if treated_participants.include?(participant)

    # Calculate base amount from line items
    base_amount = line_items
      .joins(:line_item_participants)
      .where(line_item_participants: {participant_id: participant.id})
      .sum { |item| item.amount_per_participant }

    # Add proportional share of fees minus discounts
    net_adjustment = total_fees - total_discounts
    if subtotal > 0 && net_adjustment != 0
      proportion = base_amount / subtotal
      base_amount += (net_adjustment * proportion)
    end

    # If this participant isn't treated, they also need to cover treated participants
    if treats.any?
      treated_total = treated_participants.sum { |tp| amount_owed_by_base(tp) }
      non_treated_count = participants.count - treated_participants.count
      base_amount += (treated_total / non_treated_count) if non_treated_count > 0
    end

    base_amount.round(2)
  end

  private

  def amount_owed_by_base(participant)
    # Base calculation without treat redistribution
    base_amount = line_items
      .joins(:line_item_participants)
      .where(line_item_participants: {participant_id: participant.id})
      .sum { |item| item.amount_per_participant }

    net_adjustment = total_fees - total_discounts
    if subtotal > 0 && net_adjustment != 0
      proportion = base_amount / subtotal
      base_amount += (net_adjustment * proportion)
    end

    base_amount
  end

  def set_defaults
    self.currency ||= "USD"
    self.status ||= "draft"
  end
end

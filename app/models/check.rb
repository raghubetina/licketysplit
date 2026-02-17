# == Schema Information
#
# Table name: checks
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  billed_on               :datetime
#  currency                :string           default("USD")
#  currency_symbol         :string           default("$")
#  grand_total             :decimal(10, 2)
#  line_items_count        :integer          default(0), not null
#  participants_count      :integer          default(0), not null
#  reasoning               :text
#  receipt_image           :string
#  restaurant_address      :string
#  restaurant_name         :string
#  restaurant_phone_number :string
#  status                  :string           default("draft")
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
# Indexes
#
#  index_checks_on_status  (status)
#
class Check < ApplicationRecord
  prepend MemoWise

  has_many_attached :receipt_images

  def receipt_image_urls
    receipt_images.map(&:url)
  end

  has_many :participants, dependent: :destroy
  has_many :line_items, dependent: :destroy
  has_many :global_fees, dependent: :destroy
  has_many :global_discounts, dependent: :destroy
  has_many :treats, dependent: :destroy
  has_many :treated_participants, through: :treats, source: :participant

  validates :currency, presence: true

  accepts_nested_attributes_for :line_items, allow_destroy: true
  accepts_nested_attributes_for :global_fees, allow_destroy: true
  accepts_nested_attributes_for :global_discounts, allow_destroy: true
  accepts_nested_attributes_for :participants, allow_destroy: true

  enum :status, {parsing: "parsing", draft: "draft", reviewing: "reviewing", finalized: "finalized"}

  def subtotal
    line_items.sum { |item| item.total_with_addons }
  end
  memo_wise :subtotal

  def total_fees
    global_fees.sum(:amount)
  end
  memo_wise :total_fees

  def total_discounts
    global_discounts.sum(:amount)
  end
  memo_wise :total_discounts

  def calculated_total
    subtotal + total_fees - total_discounts
  end
  memo_wise :calculated_total

  def amount_owed_by(participant)
    return 0.0 if treated_participants.include?(participant)

    base_amount = calculate_base_amount(participant)

    if treats.any?
      treated_total = treated_participants.sum { |tp| calculate_base_amount(tp) }
      non_treated_count = participants.count - treated_participants.count
      base_amount += (treated_total / non_treated_count) if non_treated_count > 0
    end

    base_amount.round(2)
  end
  memo_wise :amount_owed_by

  def tip
    global_fees.tip.first
  end

  def has_tip?
    global_fees.tip.exists?
  end

  def tippable_amount
    subtotal
  end

  private

  def calculate_base_amount(participant)
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
end

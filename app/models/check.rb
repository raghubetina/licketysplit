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
#  split_mode              :string           default("itemized"), not null
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

  validates :currency, presence: true

  accepts_nested_attributes_for :line_items, allow_destroy: true
  accepts_nested_attributes_for :global_fees, allow_destroy: true
  accepts_nested_attributes_for :global_discounts, allow_destroy: true
  accepts_nested_attributes_for :participants, allow_destroy: true

  enum :status, {parsing: "parsing", draft: "draft", reviewing: "reviewing", finalized: "finalized"}
  enum :split_mode, {itemized: "itemized", even: "even"}, prefix: :split

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
    if participant.is_being_treated?
      0.0
    elsif split_even?
      even_split_amount.round(2)
    else
      (calculate_base_amount(participant) + treatment_redistribution_amount_for(participant)).round(2)
    end
  end
  memo_wise :amount_owed_by

  def non_treated_count
    participants.count - treated_participants.count
  end
  memo_wise :non_treated_count

  # In even mode treated participants pay nothing, so the redistribution is
  # simply dividing the whole check among everyone else.
  def even_split_amount
    return 0.0 if non_treated_count.zero?
    calculated_total / non_treated_count
  end
  memo_wise :even_split_amount

  def treated_participants
    participants.treated.to_a
  end
  memo_wise :treated_participants

  def treatment_redistribution_amount_for(participant)
    return 0.0 if treated_participants.empty? || participant.is_being_treated?

    non_treated_count = participants.count - treated_participants.count
    return 0.0 if non_treated_count <= 0

    treated_total / non_treated_count
  end
  memo_wise :treatment_redistribution_amount_for

  def treated_coverage_amount_for(participant)
    return 0.0 unless treated_participants.include?(participant)

    calculate_base_amount(participant)
  end
  memo_wise :treated_coverage_amount_for

  def treated_total
    treated_participants.sum { |treated_participant| calculate_base_amount(treated_participant) }
  end
  memo_wise :treated_total

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
    base_amount = line_items.sum { |item| item.amount_for(participant) }

    net_adjustment = total_fees - total_discounts
    if subtotal > 0 && net_adjustment != 0
      proportion = base_amount / subtotal
      base_amount += (net_adjustment * proportion)
    end

    base_amount
  end
end

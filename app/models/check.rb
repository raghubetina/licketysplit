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

  MAX_RECEIPT_IMAGES = 8
  MAX_RECEIPT_IMAGE_SIZE = 15.megabytes
  ALLOWED_RECEIPT_IMAGE_TYPES = %w[image/jpeg image/png image/webp image/heic image/heif image/gif].freeze
  ALLOWED_RECEIPT_TYPES = (ALLOWED_RECEIPT_IMAGE_TYPES + [ReceiptParser::PDF_CONTENT_TYPE]).freeze

  # Real parses run 7-25s (slowest observed in production: 25.2s). Past a minute
  # the parse is far enough outside that range to tell the user something is
  # wrong and offer a retry, without claiming certainty.
  #
  # Note that absence of streamed reasoning is NOT a usable liveness signal:
  # `summary: :auto` leaves it to the model, and 30 of 62 successful parses in
  # production streamed no reasoning at all.
  PARSE_SLOW_AFTER = 60.seconds

  # A worker that dies mid-parse (OOM, deploy, host restart) leaves its check in
  # "parsing" with no recovery path: SolidQueue fails the claimed job outside of
  # #perform, so ParseReceiptJob's own rescue never runs. This threshold is the
  # point at which we stop waiting and record the parse as failed.
  STRANDED_PARSE_AFTER = 15.minutes

  # Images are handed to OpenAI (and re-fetched on any retry) at high detail.
  # Delivering a width-capped, quality-optimized JPG instead of the full-size
  # original cuts Cloudinary egress by an order of magnitude and normalizes
  # HEIC/other formats to something the vision API accepts, while staying well
  # above the resolution the model actually samples.
  RECEIPT_DELIVERY_TRANSFORMATION = {
    width: 1600, crop: "limit", quality: "auto:good", fetch_format: "jpg"
  }.freeze

  has_many_attached :receipt_images

  # Must go through Active Storage rather than Cloudinary::Utils.cloudinary_url,
  # which takes a public id verbatim and so omits the folder the service is
  # configured with, yielding a 404 for every image.
  #
  # PDFs deliberately skip the transformation: Cloudinary renders page 1 of a PDF
  # and silently discards the rest, so a multi-page invoice would lose every page
  # after the first. The parser sends those through to OpenAI whole instead.
  def receipt_parser_inputs
    receipt_images.map do |attachment|
      url = if attachment.content_type == ReceiptParser::PDF_CONTENT_TYPE
        attachment.url
      else
        attachment.url(**RECEIPT_DELIVERY_TRANSFORMATION)
      end

      {url: url, content_type: attachment.content_type}
    end
  end

  has_many :participants, dependent: :destroy
  has_many :line_items, dependent: :destroy
  has_many :global_fees, dependent: :destroy
  has_many :global_discounts, dependent: :destroy

  validates :currency, presence: true
  validate :receipt_images_within_limits

  accepts_nested_attributes_for :line_items, allow_destroy: true
  accepts_nested_attributes_for :global_fees, allow_destroy: true
  accepts_nested_attributes_for :global_discounts, allow_destroy: true
  accepts_nested_attributes_for :participants, allow_destroy: true

  enum :status, {parsing: "parsing", draft: "draft", reviewing: "reviewing", finalized: "finalized", failed: "failed"}
  enum :split_mode, {itemized: "itemized", even: "even"}, prefix: :split

  scope :stranded_in_parsing, -> { parsing.where(updated_at: ..STRANDED_PARSE_AFTER.ago) }

  def parsing_for
    Time.current - updated_at
  end

  # Retrying a parse that is still plausibly running would race a second job
  # against it for the same line items, so only offer it once the parse is well
  # outside its normal range.
  def parse_retryable?
    failed? || draft? || (parsing? && parsing_for >= PARSE_SLOW_AFTER)
  end

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
    return 0.0 if participant.is_being_treated?
    reconciled_amounts[participant.id] || 0.0
  end
  memo_wise :amount_owed_by

  # Rounding each participant's share independently lets the rounded shares
  # drift from the total (e.g. $10.00 three ways is 3 * $3.33 = $9.99). Round
  # once here and hand the leftover pennies to the largest fractional
  # remainders so the displayed shares always sum to the exact payer total.
  def reconciled_amounts
    payers = participants.reject(&:is_being_treated?)
    return {} if payers.empty?

    exact = payers.map { |participant| [participant.id, exact_amount_owed_by(participant)] }
    floored = {}
    fractions = []
    exact.each do |id, amount|
      cents = amount * 100
      whole = cents.floor
      floored[id] = whole
      fractions << [id, cents - whole]
    end

    leftover = exact.sum { |_, amount| amount * 100 }.round - floored.values.sum
    ordered = fractions.each_with_index.sort_by { |(_, fraction), index| [-fraction, index] }
    leftover.to_i.times { |i| floored[ordered[i % ordered.size].first.first] += 1 }

    floored.transform_values { |cents| BigDecimal(cents) / 100 }
  end
  memo_wise :reconciled_amounts

  def non_treated_count
    participants_count - treated_participants.size
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

  def exact_amount_owed_by(participant)
    if split_even?
      even_split_amount
    else
      calculate_base_amount(participant) + treatment_redistribution_amount_for(participant)
    end
  end

  def receipt_images_within_limits
    return unless receipt_images.attached?

    if receipt_images.size > MAX_RECEIPT_IMAGES
      errors.add(:receipt_images, "cannot exceed #{MAX_RECEIPT_IMAGES} files")
    end

    receipt_images.each do |image|
      unless ALLOWED_RECEIPT_TYPES.include?(image.content_type)
        errors.add(:receipt_images, "must be a PDF, or a JPEG, PNG, WebP, HEIC, or GIF image")
      end

      if image.blob.byte_size > MAX_RECEIPT_IMAGE_SIZE
        errors.add(:receipt_images, "must each be smaller than #{MAX_RECEIPT_IMAGE_SIZE / 1.megabyte}MB")
      end
    end
  end

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

class ParseReceiptJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3 do |job, error|
    check = job.arguments.first
    Rails.logger.error "Receipt parsing permanently failed for check #{check.id}: #{error.message}"

    check.update!(status: "draft")
    check.broadcast_refresh
  end

  def perform(check)
    parser = ReceiptParser.new(check.receipt_image_url)
    parsed_data = parser.parse

    check.update!(
      restaurant_name: parsed_data[:restaurant_name],
      restaurant_address: parsed_data[:restaurant_address],
      restaurant_phone_number: parsed_data[:restaurant_phone_number],
      billed_on: parsed_data[:billed_on],
      grand_total: parsed_data[:grand_total],
      currency: parsed_data[:currency],
      currency_symbol: parsed_data[:currency_symbol],
      line_items_attributes: parsed_data[:line_items_attributes],
      global_fees_attributes: parsed_data[:global_fees_attributes],
      global_discounts_attributes: parsed_data[:global_discounts_attributes]
    )

    check.update!(status: "reviewing")
    check.broadcast_refresh
  end
end

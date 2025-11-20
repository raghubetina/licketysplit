class ReceiptReviewsController < ApplicationController
  def index
    @receipts = load_all_receipts
  end

  def show
    @receipt_number = params[:id]
    @image_path = "/receipts/#{@receipt_number}-receipt.jpg"
    @parsed_data = load_parsed_data(@receipt_number)

    unless @parsed_data
      redirect_to receipt_reviews_path, alert: "Receipt #{@receipt_number} not found"
    end
  end

  private

  def load_all_receipts
    fixture_dir = Rails.root.join("spec/fixtures/parsed_receipts")
    receipts = []

    Dir.glob(fixture_dir.join("*_parsed.json")).sort.each do |file|
      receipt_number = File.basename(file).match(/(\d+)_parsed/)[1]
      parsed_data = JSON.parse(File.read(file), symbolize_names: true)

      receipts << {
        number: receipt_number,
        restaurant: parsed_data[:restaurant_name],
        total: parsed_data[:grand_total],
        date: parsed_data[:billed_on],
        item_count: parsed_data[:line_items_attributes].size,
        fee_count: parsed_data[:global_fees_attributes].size,
        discount_count: parsed_data[:global_discounts_attributes].size,
        addon_count: count_addons(parsed_data[:line_items_attributes])
      }
    end

    receipts
  end

  def load_parsed_data(receipt_number)
    fixture_file = Rails.root.join("spec/fixtures/parsed_receipts/#{receipt_number}_parsed.json")
    return nil unless File.exist?(fixture_file)

    JSON.parse(File.read(fixture_file), symbolize_names: true)
  end

  def count_addons(line_items)
    line_items.sum { |item| item[:addons_attributes]&.size || 0 }
  end
end

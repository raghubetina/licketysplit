#!/usr/bin/env ruby
# Test script to verify receipt parsing works
# Run with: rails runner test_receipt_parser.rb

require "dotenv/load"

# Pick one of our test receipts
receipt_path = Rails.root.join("spec/fixtures/files/receipts/1005-receipt.jpg")

unless File.exist?(receipt_path)
  puts "Error: Receipt file not found at #{receipt_path}"
  exit 1
end

puts "Testing ReceiptParser with: #{receipt_path}"
puts "-" * 50

begin
  parser = ReceiptParser.new(receipt_path)
  result = parser.parse

  puts "✅ Successfully parsed receipt!"
  puts
  puts "Restaurant: #{result[:restaurant_name]}"
  puts "Total: $#{result[:grand_total]}"
  puts "Date: #{result[:billed_on]}"
  puts
  puts "Line Items (#{result[:line_items_attributes].size}):"
  result[:line_items_attributes].each_with_index do |item, i|
    puts "  #{i + 1}. #{item[:description]} (qty: #{item[:quantity]}) - $#{item[:unit_price]}"
    if item[:addons_attributes].present?
      item[:addons_attributes].each do |addon|
        puts "     + #{addon[:description]} - $#{addon[:unit_price]}"
      end
    end
  end
  puts
  puts "Global Fees (#{result[:global_fees_attributes].size}):"
  result[:global_fees_attributes].each do |fee|
    puts "  - #{fee[:description]}: $#{fee[:amount]}"
  end
  puts
  puts "Global Discounts (#{result[:global_discounts_attributes].size}):"
  result[:global_discounts_attributes].each do |discount|
    puts "  - #{discount[:description]}: $#{discount[:amount]}"
  end

  puts
  puts "Full parsed data:"
  pp result
rescue => e
  puts "❌ Error parsing receipt: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end

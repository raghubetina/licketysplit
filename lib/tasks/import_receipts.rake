namespace :receipts do
  desc "Import parsed receipt fixtures into the database"
  task import: :environment do
    fixture_dir = Rails.root.join("spec/fixtures/parsed_receipts")
    imported = 0
    failed = 0
    errors = []

    puts "=" * 60
    puts "Importing Parsed Receipts into Database"
    puts "=" * 60

    Dir.glob(fixture_dir.join("*_parsed.json")).sort.each do |file|
      receipt_number = File.basename(file).match(/(\d+)_parsed/)[1]

      begin
        parsed_data = JSON.parse(File.read(file), symbolize_names: true)

        check = Check.create!(
          restaurant_name: parsed_data[:restaurant_name],
          restaurant_address: parsed_data[:restaurant_address],
          restaurant_phone_number: parsed_data[:restaurant_phone_number],
          billed_on: parsed_data[:billed_on],
          grand_total: parsed_data[:grand_total],
          currency: parsed_data[:currency],
          status: "draft",
          line_items_attributes: parsed_data[:line_items_attributes],
          global_fees_attributes: parsed_data[:global_fees_attributes],
          global_discounts_attributes: parsed_data[:global_discounts_attributes]
        )

        image_path = Rails.root.join("spec/fixtures/files/receipts/#{receipt_number}-receipt.jpg")
        if File.exist?(image_path)
          check.receipt_image.attach(
            io: File.open(image_path),
            filename: "#{receipt_number}-receipt.jpg",
            content_type: "image/jpeg"
          )
        end

        imported += 1
        puts "✓ Imported receipt #{receipt_number}: #{check.restaurant_name} - $#{check.grand_total}"

        warnings_found = false
        check.line_items.each do |item|
          if item.has_warnings?
            warnings_found = true
            puts "  ⚠ Line Item '#{item.description}' warnings:"
            item.full_warnings_messages.each do |warning|
              puts "    - #{warning}"
            end
          end

          item.addons.each do |addon|
            if addon.has_warnings?
              warnings_found = true
              puts "  ⚠ Addon '#{addon.description}' warnings:"
              addon.full_warnings_messages.each do |warning|
                puts "    - #{warning}"
              end
            end
          end
        end

        puts "  ℹ️  Data imported with warnings - please review" if warnings_found
      rescue => e
        failed += 1
        errors << {receipt: receipt_number, error: e.message}
        puts "✗ Failed to import receipt #{receipt_number}: #{e.message}"
      end
    end

    puts
    puts "=" * 60
    puts "Import Summary"
    puts "=" * 60
    puts "Successfully imported: #{imported}"
    puts "Failed: #{failed}"

    if errors.any?
      puts
      puts "Errors:"
      errors.each do |error|
        puts "  Receipt #{error[:receipt]}: #{error[:error]}"
      end
    end

    puts
    puts "Total checks in database: #{Check.count}"
    puts "Total line items: #{LineItem.count}"
    puts "Total global fees: #{GlobalFee.count}"
    puts "Total global discounts: #{GlobalDiscount.count}"
    puts "Total addons: #{Addon.count}"
  end

  desc "Clear all imported receipts from the database"
  task clear: :environment do
    puts "Clearing all receipts from database..."

    LineItemParticipant.destroy_all
    Addon.destroy_all
    LineItem.destroy_all
    GlobalFee.destroy_all
    GlobalDiscount.destroy_all
    Treat.destroy_all
    Participant.destroy_all
    Check.destroy_all

    puts "Database cleared."
    puts "Remaining records:"
    puts "  Checks: #{Check.count}"
    puts "  Line Items: #{LineItem.count}"
    puts "  Participants: #{Participant.count}"
  end
end

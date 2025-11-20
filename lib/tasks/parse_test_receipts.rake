namespace :receipts do
  desc "Parse all test receipts and store responses as fixtures"
  task parse_fixtures: :environment do
    require "json"
    require "fileutils"

    receipt_dir = Rails.root.join("spec/fixtures/files/receipts")
    output_dir = Rails.root.join("spec/fixtures/parsed_receipts")

    FileUtils.mkdir_p(output_dir)

    receipt_files = Dir.glob(receipt_dir.join("*.jpg")).sort

    puts "=" * 60
    puts "Receipt Parser Test Suite"
    puts "=" * 60
    puts "Found #{receipt_files.length} receipts to parse"
    puts

    results = []
    successful = 0
    failed = 0

    receipt_files.each_with_index do |receipt_path, index|
      filename = File.basename(receipt_path)
      receipt_number = filename.match(/(\d+)/)[1]

      puts "#{index + 1}/#{receipt_files.length}: Processing #{filename}..."

      begin
        parser = ReceiptParser.new(receipt_path)
        parsed_data = parser.parse

        output_file = output_dir.join("#{receipt_number}_parsed.json")
        File.write(output_file, JSON.pretty_generate(parsed_data))

        result = {
          receipt: filename,
          status: "success",
          restaurant: parsed_data[:restaurant_name],
          total: parsed_data[:grand_total],
          line_items: parsed_data[:line_items_attributes].size,
          fees: parsed_data[:global_fees_attributes].size,
          discounts: parsed_data[:global_discounts_attributes].size,
          addons: parsed_data[:line_items_attributes].sum { |item|
            item[:addons_attributes]&.size || 0
          }
        }

        successful += 1
        puts "  ✓ Success: #{result[:restaurant]} - $#{result[:total]}"
        puts "    Items: #{result[:line_items]}, Fees: #{result[:fees]}, " \
             "Discounts: #{result[:discounts]}, Addons: #{result[:addons]}"
      rescue => e
        failed += 1
        result = {
          receipt: filename,
          status: "failed",
          error: e.message
        }

        puts "  ✗ Failed: #{e.message}"

        error_file = output_dir.join("#{receipt_number}_error.json")
        File.write(error_file, JSON.pretty_generate({
          receipt: filename,
          error: e.message,
          backtrace: e.backtrace.first(5)
        }))
      end

      results << result
      puts
    end

    puts "=" * 60
    puts "Summary Report"
    puts "=" * 60
    puts "Total Receipts: #{receipt_files.length}"
    puts "Successful: #{successful} (#{(successful * 100.0 / receipt_files.length).round(1)}%)"
    puts "Failed: #{failed} (#{(failed * 100.0 / receipt_files.length).round(1)}%)"
    puts

    if successful > 0
      puts "Successfully Parsed Receipts:"
      results.select { |r| r[:status] == "success" }.each do |result|
        puts "  • #{result[:receipt]}: #{result[:restaurant]} - $#{result[:total]}"
        puts "    └─ #{result[:line_items]} items, #{result[:fees]} fees, " \
             "#{result[:discounts]} discounts, #{result[:addons]} addons"
      end
      puts
    end

    if failed > 0
      puts "Failed Receipts:"
      results.select { |r| r[:status] == "failed" }.each do |result|
        puts "  • #{result[:receipt]}: #{result[:error].truncate(60)}"
      end
      puts
    end

    if successful > 0
      successful_results = results.select { |r| r[:status] == "success" }
      avg_items = successful_results.sum { |r| r[:line_items] } / successful_results.length.to_f
      avg_fees = successful_results.sum { |r| r[:fees] } / successful_results.length.to_f
      total_value = successful_results.sum { |r| r[:total] }

      puts "Statistics:"
      puts "  Average items per receipt: #{avg_items.round(1)}"
      puts "  Average fees per receipt: #{avg_fees.round(1)}"
      puts "  Total value of receipts: $#{total_value.round(2)}"
      puts
    end

    report_file = output_dir.join("parsing_report.json")
    File.write(report_file, JSON.pretty_generate({
      timestamp: Time.current.iso8601,
      total_receipts: receipt_files.length,
      successful: successful,
      failed: failed,
      results: results
    }))

    puts "Full report saved to: #{report_file}"
    puts "Parsed fixtures saved to: #{output_dir}"
    puts

    puts "Note: Check your OpenAI dashboard for actual API usage and costs."
    puts "Estimated tokens used: ~#{successful * 1500} tokens"
    puts
  end

  desc "Load a parsed receipt fixture for testing"
  task :load_fixture, [:receipt_number] => :environment do |t, args|
    receipt_number = args[:receipt_number]
    fixture_file = Rails.root.join("spec/fixtures/parsed_receipts/#{receipt_number}_parsed.json")

    if File.exist?(fixture_file)
      data = JSON.parse(File.read(fixture_file), symbolize_names: true)

      puts "Loaded fixture for receipt #{receipt_number}:"
      puts "Restaurant: #{data[:restaurant_name]}"
      puts "Total: $#{data[:grand_total]}"
      puts "Items: #{data[:line_items_attributes].size}"
    else
      puts "Fixture not found: #{fixture_file}"
    end
  end

  desc "Generate FactoryBot factories from parsed receipts"
  task generate_factories: :environment do
    output_dir = Rails.root.join("spec/fixtures/parsed_receipts")
    factory_file = Rails.root.join("spec/factories/receipt_fixtures.rb")

    fixtures = Dir.glob(output_dir.join("*_parsed.json")).sort

    factory_content = "# Auto-generated receipt fixture factories\n"
    factory_content += "# Generated at: #{Time.current.iso8601}\n\n"
    factory_content += "FactoryBot.define do\n"

    fixtures.each do |fixture_path|
      receipt_number = File.basename(fixture_path).match(/(\d+)/)[1]
      data = JSON.parse(File.read(fixture_path), symbolize_names: true)

      factory_content += "  factory :check_#{receipt_number}, class: 'Check' do\n"
      factory_content += "    restaurant_name { #{data[:restaurant_name].inspect} }\n"
      factory_content += "    grand_total { #{data[:grand_total]} }\n"
      factory_content += "    billed_on { #{data[:billed_on].inspect} }\n"
      factory_content += "    status { 'reviewing' }\n"
      factory_content += "\n"
      factory_content += "    after(:create) do |check|\n"

      if data[:line_items_attributes]&.any?
        data[:line_items_attributes].each do |item|
          factory_content += "      check.line_items.create!(\n"
          factory_content += "        description: #{item[:description].inspect},\n"
          factory_content += "        quantity: #{item[:quantity] || 1},\n"
          factory_content += "        unit_price: #{item[:unit_price]},\n"
          factory_content += "        total_price: #{item[:total_price]}\n"
          factory_content += "      )\n"
        end
      end

      if data[:global_fees_attributes]&.any?
        data[:global_fees_attributes].each do |fee|
          factory_content += "      check.global_fees.create!(\n"
          factory_content += "        description: #{fee[:description].inspect},\n"
          factory_content += "        amount: #{fee[:amount]}\n"
          factory_content += "      )\n"
        end
      end

      factory_content += "    end\n"
      factory_content += "  end\n\n"
    end

    factory_content += "end\n"

    File.write(factory_file, factory_content)
    puts "Generated #{fixtures.length} factory definitions in #{factory_file}"
  end
end

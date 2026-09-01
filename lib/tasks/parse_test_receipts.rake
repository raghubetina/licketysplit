namespace :receipts do
  desc "Re-parse the receipt fixtures and refresh spec/fixtures/parsed_receipts"
  task parse_images: :environment do
    require "json"
    require "fileutils"
    require "cloudinary"

    receipt_dir = Rails.root.join("spec/fixtures/files/receipts")
    output_dir = Rails.root.join("spec/fixtures/parsed_receipts")
    FileUtils.mkdir_p(output_dir)

    receipt_files = Dir.glob(receipt_dir.join("*.jpg")).sort
    puts "Re-parsing #{receipt_files.length} receipts. Each one is a paid vision call."
    puts

    successful = 0
    failed = 0

    receipt_files.each_with_index do |receipt_path, index|
      filename = File.basename(receipt_path)
      receipt_number = filename[/\d+/]
      public_id = "licketysplit/fixture_parse/#{receipt_number}_#{Time.now.to_i}"

      print "#{index + 1}/#{receipt_files.length} #{filename}: "

      begin
        # The parser hands OpenAI a URL, so the fixture has to be reachable over
        # the network first. Deliver it through the same transformation
        # production uses, or the fixtures would not reflect what the app sees.
        Cloudinary::Uploader.upload(receipt_path, public_id: public_id, resource_type: "image")
        url = Cloudinary::Utils.cloudinary_url(
          public_id, resource_type: "image", format: "jpg", **Check::RECEIPT_DELIVERY_TRANSFORMATION
        )

        parsed = ReceiptParser.new([{url: url, content_type: "image/jpeg"}]).parse
        File.write(output_dir.join("#{receipt_number}_parsed.json"), JSON.pretty_generate(parsed))

        successful += 1
        puts "#{parsed[:restaurant_name]} — #{parsed[:grand_total]} " \
             "(#{parsed[:line_items_attributes].size} items, " \
             "#{parsed[:global_fees_attributes].size} fees, " \
             "#{parsed[:global_discounts_attributes].size} discounts)"
      rescue => e
        failed += 1
        puts "FAILED — #{e.class}: #{e.message}"
      ensure
        Cloudinary::Uploader.destroy(public_id, resource_type: "image")
      end
    end

    puts
    puts "#{successful} parsed, #{failed} failed."
    puts "Review the diff before committing: a change here is either a real" \
         " improvement or a regression, and only reading it tells you which."
  end
end

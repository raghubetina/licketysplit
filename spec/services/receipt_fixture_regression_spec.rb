require "rails_helper"
require "cloudinary"

# Guards against the parser silently getting worse. spec/fixtures/parsed_receipts
# holds a known-good reading of each receipt in spec/fixtures/files/receipts, but
# nothing compared against them, so drift only surfaced when someone re-ran them
# by hand -- which is how a regression on handwritten tips went unnoticed.
#
# Excluded from the default suite: every example is a paid vision call.
#   bundle exec rspec --tag vision
#
# A failure here is not automatically a bug. The model may have got *better*, in
# which case the fixture is what needs updating, via:
#   bin/rails receipts:parse_images
# Read the diff before deciding which it is.
RSpec.describe "receipt fixture regression", :vision do
  fixture_dir = Rails.root.join("spec/fixtures/parsed_receipts")
  receipt_dir = Rails.root.join("spec/fixtures/files/receipts")

  Dir.glob(fixture_dir.join("*_parsed.json")).sort.each do |fixture_path|
    number = File.basename(fixture_path)[/\d+/]
    receipt_path = receipt_dir.join("#{number}-receipt.jpg")
    next unless File.exist?(receipt_path)

    it "still reads receipt #{number} the way the fixture records it" do
      expected = JSON.parse(File.read(fixture_path), symbolize_names: true)
      public_id = "licketysplit/fixture_regression/#{number}_#{Time.now.to_i}"

      begin
        Cloudinary::Uploader.upload(receipt_path.to_s, public_id: public_id, resource_type: "image")
        url = Cloudinary::Utils.cloudinary_url(
          public_id, resource_type: "image", format: "jpg", **Check::RECEIPT_DELIVERY_TRANSFORMATION
        )
        actual = ReceiptParser.new([{url: url, content_type: "image/jpeg"}]).parse
      ensure
        Cloudinary::Uploader.destroy(public_id, resource_type: "image")
      end

      aggregate_failures do
        expect(actual[:grand_total].to_f).to be_within(0.011).of(expected[:grand_total].to_f)
        expect(actual[:line_items_attributes].size).to eq(expected[:line_items_attributes].size)
        expect(actual[:global_fees_attributes].size).to eq(expected[:global_fees_attributes].size)
        expect(actual[:global_discounts_attributes].size).to eq(expected[:global_discounts_attributes].size)

        # The sum the app will actually bill people, rather than the printed
        # total the model reports -- these can disagree, and that disagreement
        # is exactly the class of bug this file exists to catch.
        billed = actual[:line_items_attributes].sum { |i|
          i[:unit_price].to_f * i[:quantity].to_i - i[:discount].to_f +
            (i[:addons_attributes] || []).sum { |a| a[:unit_price].to_f * a[:quantity].to_i - a[:discount].to_f }
        }
        expected_billed = expected[:line_items_attributes].sum { |i|
          i[:unit_price].to_f * i[:quantity].to_i - i[:discount].to_f +
            (i[:addons_attributes] || []).sum { |a| a[:unit_price].to_f * a[:quantity].to_i - a[:discount].to_f }
        }
        expect(billed).to be_within(0.011).of(expected_billed)
      end
    end
  end
end

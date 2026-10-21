require "rails_helper"

# The labels are the eval's answer key, so they are held to the standard a
# parse is: a label that bills a different total from its own grand total
# (as 1086 once did, by $12) would mark the right reading wrong.
RSpec.describe ReceiptEval::Fixture do
  it "destroys the files it uploaded when a later one fails" do
    uploaded = []
    allow(Cloudinary::Uploader).to receive(:upload) do |_path, public_id:, **|
      raise Faraday::ConnectionFailed, "reset" if uploaded.any?

      uploaded << public_id
    end
    allow(Cloudinary::Uploader).to receive(:destroy)

    expect { described_class.new("2001").upload }.to raise_error(Faraday::ConnectionFailed)
    expect(Cloudinary::Uploader).to have_received(:destroy).with(uploaded.first, resource_type: "image")
  end

  described_class.labeled.each do |fixture|
    describe "receipt #{fixture.id}" do
      it "bills the total printed on the receipt" do
        expect(ReceiptEval::Scorer.billed_total(fixture.label)).to be_within(0.005).of(fixture.label[:grand_total])
      end

      it "has the receipt to read" do
        expect(fixture.source_paths).to all(satisfy { |path| ReceiptEval::Fixture::CONTENT_TYPES.key?(File.extname(path).downcase) })
      end
    end
  end
end

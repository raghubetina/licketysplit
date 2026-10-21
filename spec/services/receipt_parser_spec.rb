require "rails_helper"

RSpec.describe ReceiptParser do
  it "refuses to spend a vision call when there are no images" do
    expect { described_class.new([]).parse }
      .to raise_error(described_class::MissingImagesError)
  end

  it "treats a blank image url as no image at all" do
    expect { described_class.new([""]).parse }
      .to raise_error(described_class::MissingImagesError)
  end

  describe "the input it builds" do
    def content_for(sources)
      described_class.new(sources).send(:build_input).first[:content].drop(1)
    end

    # Sent whole rather than as page images so OpenAI reads every page, plus the
    # PDF's own text layer.
    it "sends a pdf as a file input" do
      expect(content_for([{url: "https://example.com/invoice.pdf", content_type: "application/pdf"}]))
        .to eq([{type: :input_file, file_url: "https://example.com/invoice.pdf"}])
    end

    it "sends an image as a high-detail image input" do
      expect(content_for([{url: "https://example.com/receipt.jpg", content_type: "image/jpeg"}]))
        .to eq([{type: :input_image, image_url: "https://example.com/receipt.jpg", detail: :high}])
    end

    it "treats a bare url as an image" do
      expect(content_for(["https://example.com/receipt.jpg"]))
        .to eq([{type: :input_image, image_url: "https://example.com/receipt.jpg", detail: :high}])
    end

    it "keeps a mixed upload in the order it was attached" do
      content = content_for([
        {url: "https://example.com/a.jpg", content_type: "image/jpeg"},
        {url: "https://example.com/b.pdf", content_type: "application/pdf"}
      ])
      expect(content.pluck(:type)).to eq([:input_image, :input_file])
    end
  end

  describe "the fees it returns" do
    def fees_for(global_fees)
      parsed = {
        restaurant: {name: nil, address: nil, phone: nil}, billed_on: nil, currency: "USD",
        line_items: [], global_discounts: [], global_fees: global_fees, grand_total: 0
      }
      described_class.new([]).send(:transform_to_check_attributes, parsed)[:global_fees_attributes]
    end

    # A check keeps only one tip fee, so two would lose one on save.
    it "folds an automatic gratuity and a written-in tip into one tip" do
      fees = fees_for([
        {description: "Gratuity 18%", amount: 3.6, fee_type: "tip"},
        {description: "Tax", amount: 1.8, fee_type: "tax"},
        {description: "Additional tip", amount: 2.0, fee_type: "tip"}
      ])

      expect(fees).to contain_exactly(
        {description: "Tax", amount: 1.8, fee_type: "tax"},
        {description: "Gratuity 18% + Additional tip", amount: 5.6, fee_type: "tip"}
      )
    end

    it "leaves a single tip alone" do
      fees = fees_for([{description: "Tip", amount: 10.0, fee_type: "tip"}])

      expect(fees).to eq([{description: "Tip", amount: 10.0, fee_type: "tip"}])
    end
  end
end

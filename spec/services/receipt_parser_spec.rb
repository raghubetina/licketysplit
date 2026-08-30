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
end

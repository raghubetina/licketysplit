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
end

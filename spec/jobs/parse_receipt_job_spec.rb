require "rails_helper"

RSpec.describe ParseReceiptJob, type: :job do
  let(:parsed) do
    {
      restaurant_name: "Diner", restaurant_address: nil, restaurant_phone_number: nil,
      billed_on: nil, grand_total: 20.0, currency: "USD", currency_symbol: "$",
      line_items_attributes: [
        {position: 1, description: "Burger", quantity: 1, unit_price: 12.0, total_price: 12.0},
        {position: 2, description: "Fries", quantity: 1, unit_price: 8.0, total_price: 8.0}
      ],
      global_fees_attributes: [{description: "Tax", amount: 2.0, fee_type: "tax"}],
      global_discounts_attributes: []
    }
  end

  it "populates the check and moves it to reviewing" do
    check = Check.create!(status: "parsing", currency: "USD")
    allow_any_instance_of(ReceiptParser).to receive(:parse).and_return(parsed)

    described_class.new.perform(check)

    expect(check.reload.status).to eq("reviewing")
    expect(check.line_items.count).to eq(2)
    expect(check.global_fees.count).to eq(1)
  end

  it "is idempotent: a retry or redelivery does not duplicate line items" do
    check = Check.create!(status: "parsing", currency: "USD")
    allow_any_instance_of(ReceiptParser).to receive(:parse).and_return(parsed)

    described_class.new.perform(check)
    described_class.new.perform(check) # simulate at-least-once redelivery

    expect(check.reload.line_items.count).to eq(2)
    expect(check.global_fees.count).to eq(1)
  end

  it "marks the check failed on a non-transient error instead of raising or stranding it" do
    check = Check.create!(status: "parsing", currency: "USD")
    allow_any_instance_of(ReceiptParser).to receive(:parse).and_raise(JSON::ParserError.new("bad json"))
    allow(Rollbar).to receive(:error) if defined?(Rollbar)

    expect { described_class.new.perform(check) }.not_to raise_error
    expect(check.reload.status).to eq("failed")
  end
end

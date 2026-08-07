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

  it "marks the check failed on a non-transient error, then re-raises so the queue records a failure" do
    check = Check.create!(status: "parsing", currency: "USD")
    allow_any_instance_of(ReceiptParser).to receive(:parse).and_raise(JSON::ParserError.new("bad json"))
    allow(Rollbar).to receive(:error)

    expect { described_class.new.perform(check) }.to raise_error(JSON::ParserError)
    expect(check.reload.status).to eq("failed")
  end

  it "reports the failure to the error tracker with the check for context" do
    check = Check.create!(status: "parsing", currency: "USD")
    allow_any_instance_of(ReceiptParser).to receive(:parse).and_raise(JSON::ParserError.new("bad json"))
    allow(Rollbar).to receive(:error)

    expect { described_class.new.perform(check) }.to raise_error(JSON::ParserError)
    expect(Rollbar).to have_received(:error).with(instance_of(JSON::ParserError), check_id: check.id)
  end
end

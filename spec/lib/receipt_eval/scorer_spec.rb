require "rails_helper"

RSpec.describe ReceiptEval::Scorer do
  def receipt(line_items, fees: [], discounts: [], grand_total: nil)
    attributes = {line_items_attributes: line_items, global_fees_attributes: fees, global_discounts_attributes: discounts}
    attributes.merge(grand_total: grand_total || described_class.billed_total(attributes))
  end

  def item(description, unit_price, quantity: 1, discount: nil, addons: [])
    {description:, unit_price:, quantity:, discount:, addons_attributes: addons}.compact
  end

  let(:label) do
    receipt(
      [
        item("CK Manhattan", 5.0, quantity: 2, addons: [item("Whistle Pig Rye", 20.0, quantity: 2)]),
        item("Banana", 2.95),
        item("Whipped Cream", 2.5)
      ],
      fees: [{description: "Tax", amount: 3.1, fee_type: "tax"}]
    )
  end

  def failures(parse) = described_class.new(label, parse).score.failed

  it "passes a parse that matches the label" do
    expect(failures(label)).to be_empty
  end

  it "ignores how items are named and whether a quantity is split across lines" do
    parse = receipt(
      [
        item("Manhattan (CK)", 5.0, addons: [item("Whistle Pig 10yr", 20.0)]),
        item("Manhattan (CK)", 5.0, addons: [item("Whistle Pig 10yr", 20.0)]),
        item("BANANA", 2.95),
        item("Whipped cream", 2.5)
      ],
      fees: [{description: "Sales tax", amount: 3.1, fee_type: "tax"}]
    )

    expect(failures(parse)).to be_empty
  end

  it "ignores whether an addon on several units is written per unit or in total" do
    sandwiches = receipt([item("Santa Fe Chicken", 5.69, quantity: 2, addons: [item("Extra green chile", 0.7)])])
    parse = receipt([item("Santa Fe Chicken", 5.69, quantity: 2, addons: [item("Extra green chile", 0.35, quantity: 2)])])

    expect(described_class.new(sandwiches, parse).score.failed).to be_empty
  end

  it "compares fees by type, however many lines the receipt splits them across" do
    parse = receipt(
      label[:line_items_attributes],
      fees: [{description: "State tax", amount: 2.0, fee_type: "tax"}, {description: "City tax", amount: 1.1, fee_type: "tax"}]
    )

    expect(failures(parse)).to be_empty
  end

  it "catches a priced modifier billed as its own item" do
    parse = receipt(
      [item("CK Manhattan", 5.0, quantity: 2), item("Whistle Pig Rye", 20.0, quantity: 2), item("Banana", 2.95), item("Whipped Cream", 2.5)],
      fees: [{description: "Tax", amount: 3.1, fee_type: "tax"}]
    )

    expect(failures(parse)).to eq([:placement])
  end

  it "catches prices swapped between items even though every amount is present" do
    parse = receipt(
      [item("CK Manhattan", 5.0, quantity: 2, addons: [item("Whistle Pig Rye", 20.0, quantity: 2)]), item("Banana", 2.5), item("Whipped Cream", 2.95)],
      fees: [{description: "Tax", amount: 3.1, fee_type: "tax"}]
    )

    expect(failures(parse)).to eq([:pairing])
  end

  it "catches addons moved to another item at the same price" do
    steaks = receipt([
      item("Cheese Steak", 10.49, addons: [item("American cheese", 1.0), item("Fried onion", 0.75)]),
      item("Chix Cheesesteak", 10.49)
    ])
    parse = receipt([
      item("Cheese Steak", 10.49),
      item("Chix Cheesesteak", 10.49, addons: [item("American cheese", 1.0), item("Fried onion", 0.75)])
    ])

    expect(described_class.new(steaks, parse).score.failed).to eq([:placement])
  end

  it "catches addons moved to another item whose name reads like the first one" do
    steaks = receipt([
      item("Cheese Steak", 10.49, addons: [item("American cheese", 1.0), item("Fried onion", 0.75)]),
      item("Chix Cheesesteak", 10.49)
    ])
    parse = receipt([
      item("Cheese Steak", 10.49),
      item("Chicken Cheese Steak", 10.49, addons: [item("American cheese", 1.0), item("Fried onion", 0.75)])
    ])

    expect(described_class.new(steaks, parse).score.failed).to eq([:placement])
  end

  it "catches an addon or comp moved onto an earlier item whose name reads like the later one" do
    steaks = receipt([item("Cheese Steak", 10.49), item("Chix Cheesesteak", 10.49, addons: [item("American cheese", 1.0)])])
    parse = receipt([item("Cheesesteak", 10.49, addons: [item("American cheese", 1.0)]), item("Chicken Cheese Steak", 10.49)])
    expect(described_class.new(steaks, parse).score.failed).to eq([:placement])

    comped = receipt([item("Cheese Steak", 10.49), item("Chix Cheesesteak", 10.49, discount: 2.0)])
    parse = receipt([item("Cheesesteak", 10.49, discount: 2.0), item("Chicken Cheese Steak", 10.49)])
    expect(described_class.new(comped, parse).score.failed).to eq([:placement])
  end

  it "keeps a later item's addon and comp in place when an earlier quantity is split across lines" do
    burgers = receipt([item("Burger", 9.0, quantity: 2), item("Burger", 9.0, discount: 1.0, addons: [item("Bacon", 2.0)])])
    parse = receipt([item("Burger", 9.0), item("Burger", 9.0), item("Burger", 9.0, discount: 1.0, addons: [item("Bacon", 2.0)])])

    expect(described_class.new(burgers, parse).score.failed).to be_empty
  end

  it "catches addons and comps carried over when quantities shift between items at the same price" do
    plates = receipt([item("Burger", 10.0, quantity: 2, discount: 4.0, addons: [item("Bacon", 1.0, quantity: 2)]), item("Salad", 10.0)])
    parse = receipt([item("Burger", 10.0), item("Salad", 10.0, quantity: 2, discount: 4.0, addons: [item("Bacon", 1.0, quantity: 2)])])

    expect(described_class.new(plates, parse).score.failed).to include(:placement)
  end

  it "scores items named without Latin letters" do
    rice = receipt([item("炒饭", 10.0)])

    expect(described_class.new(rice, rice).score.failed).to be_empty
  end

  it "ignores whether a comp on several units is written on one line or split across them" do
    comped = receipt([item("Burger", 10.0, quantity: 2, discount: 4.0)])
    parse = receipt([item("Burger", 10.0, discount: 2.0), item("Burger", 10.0, discount: 2.0)])

    expect(described_class.new(comped, parse).score.failed).to be_empty
  end

  it "catches a comp moved from its item onto the whole check" do
    comped = receipt([item("Chips", 6.0, discount: 6.0), item("Burger", 12.0)])
    parse = receipt([item("Chips", 6.0), item("Burger", 12.0)], discounts: [{description: "Comp", amount: 6.0}])

    expect(described_class.new(comped, parse).score.failed).to eq([:placement])
  end

  it "catches a total the app would bill differently from the receipt" do
    parse = receipt(label[:line_items_attributes], fees: [], grand_total: label[:grand_total])

    expect(failures(parse)).to contain_exactly(:total, :fees)
  end
end

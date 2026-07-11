require "rails_helper"

RSpec.describe Check, type: :model do
  describe "#amount_owed_by" do
    it "sets treated participants to zero and redistributes their consumption evenly" do
      check = Check.create!
      bob = check.participants.create!(name: "Bob")
      carol = check.participants.create!(name: "Carol")
      alice = check.participants.create!(name: "Alice")
      alice.update!(being_treated: true)

      alice_item = check.line_items.create!(description: "Steak", unit_price: 30, quantity: 1)
      bob_item = check.line_items.create!(description: "Burger", unit_price: 20, quantity: 1)
      carol_item = check.line_items.create!(description: "Salad", unit_price: 10, quantity: 1)

      alice_item.line_item_participants.create!(participant: alice)
      bob_item.line_item_participants.create!(participant: bob)
      carol_item.line_item_participants.create!(participant: carol)

      expect(check.amount_owed_by(alice)).to eq(0.0)
      expect(check.amount_owed_by(bob)).to eq(35.0)
      expect(check.amount_owed_by(carol)).to eq(25.0)
    end

    it "redistributes treated totals after proportional fees and discounts are applied" do
      check = Check.create!
      bob = check.participants.create!(name: "Bob")
      alice = check.participants.create!(name: "Alice")
      alice.update!(being_treated: true)

      alice_item = check.line_items.create!(description: "Main", unit_price: 40, quantity: 1)
      bob_item = check.line_items.create!(description: "Main", unit_price: 60, quantity: 1)

      alice_item.line_item_participants.create!(participant: alice)
      bob_item.line_item_participants.create!(participant: bob)

      check.global_fees.create!(description: "Tax", amount: 10)
      check.global_discounts.create!(description: "Promo", amount: 20)

      expect(check.amount_owed_by(alice)).to eq(0.0)
      expect(check.amount_owed_by(bob)).to eq(90.0)
      expect(check.calculated_total).to eq(90)
    end

    it "charges by share count for unevenly split items" do
      check = Check.create!
      maya = check.participants.create!(name: "Maya")
      raghu = check.participants.create!(name: "Raghu")

      wine = check.line_items.create!(description: "Wine", unit_price: 14, quantity: 3, uneven_split: true)
      wine.line_item_participants.create!(participant: maya, shares: 2)
      wine.line_item_participants.create!(participant: raghu, shares: 1)

      expect(check.amount_owed_by(maya)).to eq(28.0)
      expect(check.amount_owed_by(raghu)).to eq(14.0)
    end

    it "prorates fees against uneven bases" do
      check = Check.create!
      maya = check.participants.create!(name: "Maya")
      raghu = check.participants.create!(name: "Raghu")

      wine = check.line_items.create!(description: "Wine", unit_price: 10, quantity: 3, uneven_split: true)
      wine.line_item_participants.create!(participant: maya, shares: 2)
      wine.line_item_participants.create!(participant: raghu, shares: 1)

      check.global_fees.create!(description: "Tax", amount: 3)

      # subtotal 30, fee 3: maya 20 + 2, raghu 10 + 1
      expect(check.amount_owed_by(maya)).to eq(22.0)
      expect(check.amount_owed_by(raghu)).to eq(11.0)
    end

    it "leaves under-assigned uneven remainders out of everyone's total" do
      check = Check.create!
      maya = check.participants.create!(name: "Maya")
      raghu = check.participants.create!(name: "Raghu")

      wine = check.line_items.create!(description: "Wine", unit_price: 14, quantity: 3, uneven_split: true)
      wine.line_item_participants.create!(participant: maya, shares: 1)
      wine.line_item_participants.create!(participant: raghu, shares: 1)

      expect(check.amount_owed_by(maya)).to eq(14.0)
      expect(check.amount_owed_by(raghu)).to eq(14.0)
      expect(wine.unallocated_total).to eq(14)
    end

    it "redistributes a treated participant's uneven share among the others" do
      check = Check.create!
      maya = check.participants.create!(name: "Maya")
      raghu = check.participants.create!(name: "Raghu")
      alice = check.participants.create!(name: "Alice")
      alice.update!(being_treated: true)

      wine = check.line_items.create!(description: "Wine", unit_price: 12, quantity: 4, uneven_split: true)
      wine.line_item_participants.create!(participant: maya, shares: 1)
      wine.line_item_participants.create!(participant: raghu, shares: 1)
      wine.line_item_participants.create!(participant: alice, shares: 2)

      # alice's 24 splits evenly across maya and raghu
      expect(check.amount_owed_by(alice)).to eq(0.0)
      expect(check.amount_owed_by(maya)).to eq(24.0)
      expect(check.amount_owed_by(raghu)).to eq(24.0)
    end

    it "divides the whole check evenly in even-split mode, ignoring item assignments" do
      check = Check.create!(split_mode: "even")
      maya = check.participants.create!(name: "Maya")
      raghu = check.participants.create!(name: "Raghu")

      steak = check.line_items.create!(description: "Steak", unit_price: 60, quantity: 1)
      steak.line_item_participants.create!(participant: maya)
      check.line_items.create!(description: "Salad", unit_price: 30, quantity: 1)

      check.global_fees.create!(description: "Tax", amount: 10)

      expect(check.amount_owed_by(maya)).to eq(50.0)
      expect(check.amount_owed_by(raghu)).to eq(50.0)
    end

    it "excludes treated participants from the even split and charges them nothing" do
      check = Check.create!(split_mode: "even")
      maya = check.participants.create!(name: "Maya")
      raghu = check.participants.create!(name: "Raghu")
      alice = check.participants.create!(name: "Alice")
      alice.update!(being_treated: true)

      check.line_items.create!(description: "Feast", unit_price: 90, quantity: 1)

      expect(check.amount_owed_by(alice)).to eq(0.0)
      expect(check.amount_owed_by(maya)).to eq(45.0)
      expect(check.amount_owed_by(raghu)).to eq(45.0)
    end

    it "returns zero from even_split_amount when there is nobody to charge" do
      check = Check.create!(split_mode: "even")
      check.line_items.create!(description: "Feast", unit_price: 90, quantity: 1)

      expect(check.even_split_amount).to eq(0.0)
    end
  end

  describe "penny reconciliation" do
    it "makes an even three-way split sum exactly to the total" do
      check = Check.create!(split_mode: "even")
      people = ["Amy", "Ben", "Cy"].map { |name| check.participants.create!(name: name) }
      check.line_items.create!(description: "Pizza", unit_price: 10, quantity: 1)

      owed = people.map { |person| check.amount_owed_by(person) }
      expect(owed.sum).to eq(10.0)
      expect(owed.map { |amount| amount.round(2) }.sort).to eq([3.33, 3.33, 3.34])
    end

    it "makes an itemized split with a fractional fee sum exactly to the payer total" do
      check = Check.create!
      people = ["Amy", "Ben", "Cy"].map { |name| check.participants.create!(name: name) }
      item = check.line_items.create!(description: "Platter", unit_price: 10, quantity: 1)
      people.each { |person| item.line_item_participants.create!(participant: person) }
      check.global_fees.create!(description: "Tax", amount: 1)

      owed = people.map { |person| check.amount_owed_by(person) }
      expect(owed.sum).to eq(check.calculated_total)
      expect(check.calculated_total).to eq(11.0)
    end
  end
end

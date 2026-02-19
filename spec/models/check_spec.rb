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
  end
end

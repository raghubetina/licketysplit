require "rails_helper"

RSpec.describe LineItem, type: :model do
  describe "#amount_for" do
    it "splits evenly among assignees when not in uneven mode" do
      check = Check.create!
      maya = check.participants.create!(name: "Maya")
      raghu = check.participants.create!(name: "Raghu")

      wine = check.line_items.create!(description: "Wine", unit_price: 14, quantity: 3)
      wine.line_item_participants.create!(participant: maya)
      wine.line_item_participants.create!(participant: raghu)

      expect(wine.amount_for(maya)).to eq(21)
      expect(wine.amount_for(raghu)).to eq(21)
    end

    it "charges shares times unit price in uneven mode" do
      check = Check.create!
      maya = check.participants.create!(name: "Maya")
      raghu = check.participants.create!(name: "Raghu")

      wine = check.line_items.create!(description: "Wine", unit_price: 14, quantity: 3, uneven_split: true)
      wine.line_item_participants.create!(participant: maya, shares: 2)
      wine.line_item_participants.create!(participant: raghu, shares: 1)

      expect(wine.amount_for(maya)).to eq(28)
      expect(wine.amount_for(raghu)).to eq(14)
    end

    it "returns zero for unassigned participants" do
      check = Check.create!
      maya = check.participants.create!(name: "Maya")

      wine = check.line_items.create!(description: "Wine", unit_price: 14, quantity: 3, uneven_split: true)

      expect(wine.amount_for(maya)).to eq(0)
    end

    it "distributes addons and the item discount proportionally by share fraction in uneven mode" do
      check = Check.create!
      maya = check.participants.create!(name: "Maya")
      raghu = check.participants.create!(name: "Raghu")

      pizza = check.line_items.create!(description: "Pizza", unit_price: 10, quantity: 3, discount: 3, uneven_split: true)
      pizza.addons.create!(description: "Prosciutto", unit_price: 6, quantity: 1)
      pizza.line_item_participants.create!(participant: maya, shares: 2)
      pizza.line_item_participants.create!(participant: raghu, shares: 1)

      # addons_total (6) - discount (3) = 3, split 2:1
      expect(pizza.amount_for(maya)).to eq(22)
      expect(pizza.amount_for(raghu)).to eq(11)
      expect(pizza.amount_for(maya) + pizza.amount_for(raghu)).to eq(pizza.total_with_addons)
    end
  end

  describe "#unallocated_total" do
    it "is the full item value when nobody is assigned" do
      check = Check.create!
      wine = check.line_items.create!(description: "Wine", unit_price: 14, quantity: 3)

      expect(wine.unallocated_total).to eq(42)
    end

    it "is zero when assigned in even mode" do
      check = Check.create!
      maya = check.participants.create!(name: "Maya")
      wine = check.line_items.create!(description: "Wine", unit_price: 14, quantity: 3)
      wine.line_item_participants.create!(participant: maya)

      expect(wine.unallocated_total).to eq(0)
    end

    it "is the unclaimed units in uneven mode" do
      check = Check.create!
      maya = check.participants.create!(name: "Maya")
      wine = check.line_items.create!(description: "Wine", unit_price: 14, quantity: 3, uneven_split: true)
      wine.line_item_participants.create!(participant: maya, shares: 2)

      expect(wine.unallocated_total).to eq(14)
    end

    it "clamps to zero when over-assigned" do
      check = Check.create!
      maya = check.participants.create!(name: "Maya")
      wine = check.line_items.create!(description: "Wine", unit_price: 14, quantity: 3, uneven_split: true)
      wine.line_item_participants.create!(participant: maya, shares: 5)

      expect(wine.unallocated_total).to eq(0)
    end
  end

  describe "#enable_uneven_split!" do
    it "distributes the quantity across current assignees, deterministically by name" do
      check = Check.create!
      zoe = check.participants.create!(name: "Zoe")
      abe = check.participants.create!(name: "Abe")

      wine = check.line_items.create!(description: "Wine", unit_price: 14, quantity: 3)
      wine.line_item_participants.create!(participant: zoe)
      wine.line_item_participants.create!(participant: abe)

      wine.enable_uneven_split!

      expect(wine.reload.uneven_split).to be(true)
      expect(wine.shares_for(abe)).to eq(2)
      expect(wine.shares_for(zoe)).to eq(1)
    end

    it "just flips the flag when nobody is assigned" do
      check = Check.create!
      wine = check.line_items.create!(description: "Wine", unit_price: 14, quantity: 3)

      wine.enable_uneven_split!

      expect(wine.reload.uneven_split).to be(true)
      expect(wine.total_assigned_shares).to eq(0)
    end

    it "drops assignees beyond the quantity" do
      check = Check.create!
      participants = %w[Abe Bea Cal].map { |name| check.participants.create!(name: name) }

      tiramisu = check.line_items.create!(description: "Tiramisu", unit_price: 12, quantity: 2)
      participants.each { |p| tiramisu.line_item_participants.create!(participant: p) }

      tiramisu.enable_uneven_split!

      expect(tiramisu.reload.total_assigned_shares).to eq(2)
      expect(tiramisu.participants_count).to eq(2)
    end
  end

  describe "#revert_to_even_split!" do
    it "keeps everyone with shares assigned and resets share counts" do
      check = Check.create!
      maya = check.participants.create!(name: "Maya")
      raghu = check.participants.create!(name: "Raghu")

      wine = check.line_items.create!(description: "Wine", unit_price: 14, quantity: 3, uneven_split: true)
      wine.line_item_participants.create!(participant: maya, shares: 2)
      wine.line_item_participants.create!(participant: raghu, shares: 1)

      wine.revert_to_even_split!

      expect(wine.reload.uneven_split).to be(false)
      expect(wine.line_item_participants.pluck(:shares)).to all(eq(1))
      expect(wine.participants).to contain_exactly(maya, raghu)
      expect(wine.amount_for(maya)).to eq(21)
    end
  end

  describe "warnings" do
    it "warns when more shares are assigned than the quantity" do
      check = Check.create!
      maya = check.participants.create!(name: "Maya")
      wine = check.line_items.create!(description: "Wine", unit_price: 14, quantity: 2, uneven_split: true)
      wine.line_item_participants.create!(participant: maya, shares: 3)

      wine.reload.valid?
      expect(wine.has_warnings?).to be(true)
      expect(wine.warnings_for(:quantity)).not_to be_empty
    end
  end
end

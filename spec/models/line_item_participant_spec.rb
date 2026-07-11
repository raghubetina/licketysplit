require "rails_helper"

RSpec.describe LineItemParticipant, type: :model do
  it "defaults shares to 1" do
    check = Check.create!
    maya = check.participants.create!(name: "Maya")
    item = check.line_items.create!(description: "Salad", unit_price: 10)

    lip = item.line_item_participants.create!(participant: maya)

    expect(lip.shares).to eq(1)
  end

  it "rejects zero or fractional shares" do
    check = Check.create!
    maya = check.participants.create!(name: "Maya")
    item = check.line_items.create!(description: "Salad", unit_price: 10)

    expect(item.line_item_participants.build(participant: maya, shares: 0)).not_to be_valid
    expect(item.line_item_participants.build(participant: maya, shares: 1.5)).not_to be_valid
  end

  it "maintains the participants_count counter cache across create and destroy" do
    check = Check.create!
    maya = check.participants.create!(name: "Maya")
    item = check.line_items.create!(description: "Salad", unit_price: 10)

    lip = item.line_item_participants.create!(participant: maya)
    expect(item.reload.participants_count).to eq(1)

    lip.destroy
    expect(item.reload.participants_count).to eq(0)
  end

  it "destroys a check with assigned participants without raising in the broadcast callback" do
    check = Check.create!
    maya = check.participants.create!(name: "Maya")
    item = check.line_items.create!(description: "Salad", unit_price: 10)
    item.line_item_participants.create!(participant: maya)

    expect { check.destroy }.not_to raise_error
    expect(Check.exists?(check.id)).to be false
  end
end

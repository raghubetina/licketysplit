require "rails_helper"

# LineItemsController owns assignment and share splitting: the code that decides
# what each person actually owes. It had no request coverage at all, which is
# how two CSP-blocked toggles reached production -- a control the browser refuses
# to run looks identical to a working one from Ruby's side, so these specs prove
# the server half only.
RSpec.describe "LineItems", type: :request do
  let(:check) { Check.create!(currency: "USD") }
  let!(:amy) { check.participants.create!(name: "Amy") }
  let!(:ben) { check.participants.create!(name: "Ben") }
  let(:item) { check.line_items.create!(description: "Hamachi Collar", unit_price: 12.0, quantity: 2, position: 1) }

  describe "POST create" do
    it "adds the item to the check" do
      expect {
        post check_line_items_path(check), params: {line_item: {description: "Uni", unit_price: "9.00", quantity: 1}}
      }.to change(check.line_items, :count).by(1)

      expect(response).to redirect_to(check)
    end

    it "re-renders the form rather than saving an item with no price" do
      expect {
        post check_line_items_path(check), params: {line_item: {description: "Uni", unit_price: "", quantity: 1}}
      }.not_to change(check.line_items, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH update" do
    it "changes what the item costs" do
      patch check_line_item_path(check, item), params: {line_item: {description: "Hamachi", unit_price: "15.00", quantity: 1}}

      expect(item.reload.unit_price).to eq(15.0)
      expect(item.base_total).to eq(15.0)
    end

    it "refuses a blank description instead of saving it" do
      patch check_line_item_path(check, item), params: {line_item: {description: "", unit_price: "12.00", quantity: 1}}

      expect(response).to have_http_status(:unprocessable_content)
      expect(item.reload.description).to eq("Hamachi Collar")
    end
  end

  describe "DELETE destroy" do
    it "removes the item and its assignments" do
      item.line_item_participants.create!(participant: amy)

      expect { delete check_line_item_path(check, item) }
        .to change(check.line_items, :count).by(-1)
        .and change(LineItemParticipant, :count).by(-1)
    end
  end

  describe "POST toggle_participant" do
    it "assigns someone, and charges them for it" do
      post toggle_participant_line_item_path(item), params: {participant_id: amy.id}

      expect(item.reload.participants).to eq([amy])
      expect(check.reload.amount_owed_by(amy)).to eq(24.0)
    end

    it "unassigns someone already on the item" do
      item.line_item_participants.create!(participant: amy)

      expect { post toggle_participant_line_item_path(item), params: {participant_id: amy.id} }
        .to change { item.reload.participants.count }.from(1).to(0)
    end

    it "splits the item between everyone assigned to it" do
      post toggle_participant_line_item_path(item), params: {participant_id: amy.id}
      post toggle_participant_line_item_path(item), params: {participant_id: ben.id}

      expect(check.reload.amount_owed_by(amy)).to eq(12.0)
      expect(check.reload.amount_owed_by(ben)).to eq(12.0)
    end
  end

  describe "POST toggle_all_participants" do
    it "assigns everyone on the check when nobody is assigned" do
      post toggle_all_participants_line_item_path(item)

      expect(item.reload.participant_ids).to match_array([amy.id, ben.id])
    end

    it "clears the item when everyone is already assigned" do
      [amy, ben].each { |p| item.line_item_participants.create!(participant: p) }

      post toggle_all_participants_line_item_path(item)

      expect(item.reload.participant_ids).to be_empty
    end

    it "tops up a partial assignment rather than clearing it" do
      item.line_item_participants.create!(participant: amy)

      post toggle_all_participants_line_item_path(item)

      expect(item.reload.participant_ids).to match_array([amy.id, ben.id])
    end
  end

  describe "uneven splitting" do
    before { [amy, ben].each { |p| item.line_item_participants.create!(participant: p) } }

    it "seeds shares by dividing the quantity across assignees" do
      post make_uneven_line_item_path(item)

      expect(item.reload).to be_uneven_split
      expect(item.line_item_participants.pluck(:shares)).to eq([1, 1])
    end

    it "charges by share once uneven" do
      post make_uneven_line_item_path(item)
      post increment_share_line_item_path(item), params: {participant_id: amy.id}

      # Amy now holds 2 of 3 shares of a $24 item.
      expect(item.reload.shares_for(amy)).to eq(2)
      expect(item.amount_for(amy)).to eq(24.0)
      expect(item.amount_for(ben)).to eq(12.0)
    end

    it "drops the assignment when the last share is decremented away" do
      post make_uneven_line_item_path(item)

      expect { post decrement_share_line_item_path(item), params: {participant_id: ben.id} }
        .to change { item.reload.participants.include?(ben) }.from(true).to(false)
    end

    it "collapses back to equal shares on revert" do
      post make_uneven_line_item_path(item)
      post increment_share_line_item_path(item), params: {participant_id: amy.id}

      post revert_to_even_line_item_path(item)

      expect(item.reload).not_to be_uneven_split
      expect(item.line_item_participants.pluck(:shares)).to eq([1, 1])
    end
  end

  # A participant from another check must never end up owing part of this one.
  # LineItemParticipant validates this; the request is rejected rather than
  # raising, because test env runs with show_exceptions = :rescuable.
  it "refuses to assign someone who is not on this check" do
    stranger = Check.create!(currency: "USD").participants.create!(name: "Zoe")

    expect {
      post toggle_participant_line_item_path(item), params: {participant_id: stranger.id}
    }.not_to change(LineItemParticipant, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(item.reload.participants).to be_empty
  end
end

require "rails_helper"

RSpec.describe "Addons", type: :request do
  let(:check) { Check.create!(currency: "USD") }
  let(:item) { check.line_items.create!(description: "Burger", unit_price: 12.0, quantity: 1, position: 1) }
  let!(:addon) { item.addons.create!(description: "Extra cheese", unit_price: 1.5, quantity: 1) }

  describe "PATCH update" do
    it "changes what the addon adds to its line item" do
      patch line_item_addon_path(item, addon), params: {addon: {description: "Extra cheese", unit_price: "2.50", quantity: 1}}

      expect(item.reload.total_with_addons).to eq(14.5)
    end

    it "refuses a blank description instead of saving it" do
      patch line_item_addon_path(item, addon), params: {addon: {description: "", unit_price: "1.50", quantity: 1}}

      expect(response).to have_http_status(:unprocessable_content)
      expect(addon.reload.description).to eq("Extra cheese")
    end
  end

  describe "DELETE destroy" do
    it "takes the addon back off the line item total" do
      expect { delete line_item_addon_path(item, addon) }
        .to change(item.addons, :count).by(-1)

      expect(item.reload.total_with_addons).to eq(12.0)
    end
  end
end

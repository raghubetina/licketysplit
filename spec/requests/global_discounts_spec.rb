require "rails_helper"

RSpec.describe "GlobalDiscounts", type: :request do
  let(:check) { Check.create!(currency: "USD") }
  let!(:item) { check.line_items.create!(description: "Hamachi Collar", unit_price: 40.0, quantity: 1, position: 1) }

  describe "POST create" do
    it "subtracts the discount from the total" do
      expect {
        post check_global_discounts_path(check), params: {global_discount: {description: "Happy hour", amount: "6.00"}}
      }.to change(check.global_discounts, :count).by(1)

      expect(check.reload.calculated_total).to eq(34.0)
    end

    it "re-renders rather than saving a discount with no amount" do
      expect {
        post check_global_discounts_path(check), params: {global_discount: {description: "Happy hour", amount: ""}}
      }.not_to change(check.global_discounts, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH update" do
    it "changes what comes off the total" do
      discount = check.global_discounts.create!(description: "Happy hour", amount: 6.0)

      patch check_global_discount_path(check, discount), params: {global_discount: {description: "Happy hour", amount: "10.00"}}

      expect(check.reload.calculated_total).to eq(30.0)
    end
  end

  describe "DELETE destroy" do
    it "puts the money back on the total" do
      discount = check.global_discounts.create!(description: "Happy hour", amount: 6.0)

      delete check_global_discount_path(check, discount)

      expect(check.reload.calculated_total).to eq(40.0)
    end
  end
end

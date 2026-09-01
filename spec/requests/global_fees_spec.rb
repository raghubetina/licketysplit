require "rails_helper"

RSpec.describe "GlobalFees", type: :request do
  let(:check) { Check.create!(currency: "USD") }
  let!(:item) { check.line_items.create!(description: "Hamachi Collar", unit_price: 40.0, quantity: 1, position: 1) }

  describe "POST create" do
    it "adds a fee and counts it toward the total" do
      expect {
        post check_global_fees_path(check), params: {global_fee: {description: "Tax", amount: "3.20", fee_type: "tax"}}
      }.to change(check.global_fees, :count).by(1)

      expect(check.reload.calculated_total).to eq(43.2)
    end

    it "re-renders rather than saving a fee with no amount" do
      expect {
        post check_global_fees_path(check), params: {global_fee: {description: "Tax", amount: "", fee_type: "tax"}}
      }.not_to change(check.global_fees, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE destroy" do
    it "removes the fee from the total" do
      fee = check.global_fees.create!(description: "Tax", amount: 3.2, fee_type: "tax")

      delete check_global_fee_path(check, fee)

      expect(check.reload.calculated_total).to eq(40.0)
    end
  end

  describe "POST set_tip" do
    # Tip is a percentage of the pre-fee subtotal, not of the grand total, so
    # adding tax first must not inflate the tip.
    it "calculates the tip from the subtotal" do
      check.global_fees.create!(description: "Tax", amount: 10.0, fee_type: "tax")

      post set_tip_check_global_fees_path(check), params: {percentage: 20}

      expect(check.reload.tip.amount).to eq(8.0)
    end

    it "replaces an existing tip instead of stacking a second one" do
      post set_tip_check_global_fees_path(check), params: {percentage: 20}
      post set_tip_check_global_fees_path(check), params: {percentage: 25}

      expect(check.reload.global_fees.tip.count).to eq(1)
      expect(check.tip.amount).to eq(10.0)
    end
  end
end

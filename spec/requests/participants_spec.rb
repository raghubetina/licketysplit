require "rails_helper"

RSpec.describe "Participants", type: :request do
  describe "POST toggle_treated" do
    it "refuses to treat the last remaining payer" do
      check = Check.create!(currency: "USD")
      amy = check.participants.create!(name: "Amy")
      ben = check.participants.create!(name: "Ben")

      # Treating Ben is fine — Amy still pays.
      post toggle_treated_check_participant_path(check, ben)
      expect(ben.reload.being_treated?).to be true

      # Treating Amy too would leave nobody paying — must be blocked.
      post toggle_treated_check_participant_path(check, amy)
      expect(amy.reload.being_treated?).to be false
    end

    it "still allows un-treating a participant" do
      check = Check.create!(currency: "USD")
      check.participants.create!(name: "Amy")
      ben = check.participants.create!(name: "Ben", being_treated: true)

      post toggle_treated_check_participant_path(check, ben)

      expect(ben.reload.being_treated?).to be false
    end
  end
end

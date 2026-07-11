require "rails_helper"

# Regression coverage for the anonymous-abuse and mass-assignment hardening.
RSpec.describe "Security hardening", type: :request do
  describe "the removed /backdoor route" do
    it "no longer exists" do
      get "/backdoor"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "check status is not mass-assignable" do
    it "ignores a status set through the update form but applies permitted fields" do
      check = Check.create!(status: "reviewing", currency: "USD")

      patch check_path(check), params: {check: {status: "parsing", restaurant_name: "Renamed"}}

      expect(check.reload.status).to eq("reviewing")
      expect(check.restaurant_name).to eq("Renamed")
    end
  end

  describe "retry_parse" do
    it "re-enqueues parsing and returns a failed check to parsing" do
      check = Check.create!(status: "failed", currency: "USD")

      expect {
        post retry_parse_check_path(check)
      }.to have_enqueued_job(ParseReceiptJob)

      expect(check.reload.status).to eq("parsing")
    end

    it "does nothing for a check that is already reviewing" do
      check = Check.create!(status: "reviewing", currency: "USD")

      expect {
        post retry_parse_check_path(check)
      }.not_to have_enqueued_job(ParseReceiptJob)

      expect(check.reload.status).to eq("reviewing")
    end
  end
end

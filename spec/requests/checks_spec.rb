require "rails_helper"

RSpec.describe "Checks", type: :request do
  describe "POST create" do
    # file_field with multiple: true submits a hidden empty value, so this is
    # what an empty form actually sends -- not a missing param.
    it "rejects a submission with no file chosen instead of parsing zero images" do
      expect {
        post checks_path, params: {receipt_images: [""]}
      }.not_to change(Check, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST retry_parse" do
    def parsing_check_last_touched(ago)
      Check.create!(status: "parsing", currency: "USD").tap do |check|
        check.update_column(:updated_at, ago)
      end
    end

    it "re-enqueues a parse that stalled well past its normal duration" do
      check = parsing_check_last_touched(5.minutes.ago)

      expect {
        post retry_parse_check_path(check)
      }.to have_enqueued_job(ParseReceiptJob).with(check)

      expect(check.reload.status).to eq("parsing")
    end

    it "refuses to race a second job against a parse that is still running" do
      check = parsing_check_last_touched(10.seconds.ago)

      expect {
        post retry_parse_check_path(check)
      }.not_to have_enqueued_job(ParseReceiptJob)
    end

    it "still retries a failed parse" do
      check = Check.create!(status: "failed", currency: "USD")

      expect {
        post retry_parse_check_path(check)
      }.to have_enqueued_job(ParseReceiptJob).with(check)

      expect(check.reload.status).to eq("parsing")
    end
  end
end

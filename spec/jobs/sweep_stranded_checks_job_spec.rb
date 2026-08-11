require "rails_helper"

RSpec.describe SweepStrandedChecksJob, type: :job do
  before { allow(Rollbar).to receive(:error) }

  def parsing_check_last_touched(ago)
    Check.create!(status: "parsing", currency: "USD").tap do |check|
      check.update_column(:updated_at, ago)
    end
  end

  it "fails a check whose worker died mid-parse" do
    check = parsing_check_last_touched(1.hour.ago)

    described_class.new.perform

    expect(check.reload.status).to eq("failed")
  end

  it "leaves a parse that is still running alone" do
    check = parsing_check_last_touched(30.seconds.ago)

    described_class.new.perform

    expect(check.reload.status).to eq("parsing")
  end

  it "does not disturb checks that finished parsing" do
    check = Check.create!(status: "reviewing", currency: "USD")
    check.update_column(:updated_at, 1.hour.ago)

    described_class.new.perform

    expect(check.reload.status).to eq("reviewing")
  end

  it "reports the strand so it is visible rather than silently swept" do
    parsing_check_last_touched(1.hour.ago)

    described_class.new.perform

    expect(Rollbar).to have_received(:error)
      .with(instance_of(described_class::StrandedParseError), hash_including(:check_id))
  end
end

require "rails_helper"

RSpec.describe Participant, type: :model do
  describe ".parse_names" do
    context "with comma-separated names" do
      it "splits by commas" do
        expect(Participant.parse_names("Alice, Bob, Carol")).to eq(%w[Alice Bob Carol])
      end

      it "handles extra whitespace around names" do
        expect(Participant.parse_names("  Alice  ,  Bob  ,  Carol  ")).to eq(%w[Alice Bob Carol])
      end

      it "handles no spaces after commas" do
        expect(Participant.parse_names("Alice,Bob,Carol")).to eq(%w[Alice Bob Carol])
      end

      it "ignores empty entries from multiple commas" do
        expect(Participant.parse_names("Alice,,Bob,,,Carol")).to eq(%w[Alice Bob Carol])
      end

      it "preserves full names with spaces" do
        expect(Participant.parse_names("Alice Smith, Bob Doe, Carol Johnson")).to eq(["Alice Smith", "Bob Doe", "Carol Johnson"])
      end
    end

    context "with newline-separated names" do
      it "splits by newlines" do
        expect(Participant.parse_names("Alice\nBob\nCarol")).to eq(%w[Alice Bob Carol])
      end

      it "handles Windows-style line endings (CRLF)" do
        expect(Participant.parse_names("Alice\r\nBob\r\nCarol")).to eq(%w[Alice Bob Carol])
      end

      it "handles multiple blank lines" do
        expect(Participant.parse_names("Alice\n\n\nBob\n\nCarol")).to eq(%w[Alice Bob Carol])
      end

      it "handles whitespace around names" do
        expect(Participant.parse_names("  Alice  \n  Bob  \n  Carol  ")).to eq(%w[Alice Bob Carol])
      end

      it "preserves full names with spaces" do
        input = "Alice Smith\nBob Doe\nCarol Johnson"
        expect(Participant.parse_names(input)).to eq(["Alice Smith", "Bob Doe", "Carol Johnson"])
      end

      it "handles mixed internal whitespace in full names" do
        input = "Alice   Smith\nBob    Doe"
        expect(Participant.parse_names(input)).to eq(["Alice Smith", "Bob Doe"])
      end
    end

    context "with period-separated names" do
      it "splits by periods" do
        expect(Participant.parse_names("Alice. Bob. Carol")).to eq(%w[Alice Bob Carol])
      end

      it "handles no spaces after periods" do
        expect(Participant.parse_names("Alice.Bob.Carol")).to eq(%w[Alice Bob Carol])
      end

      it "handles extra whitespace" do
        expect(Participant.parse_names("  Alice  .  Bob  .  Carol  ")).to eq(%w[Alice Bob Carol])
      end

      it "ignores empty entries from multiple periods" do
        expect(Participant.parse_names("Alice..Bob...Carol")).to eq(%w[Alice Bob Carol])
      end
    end

    context "with space-separated names (fallback)" do
      it "splits by spaces" do
        expect(Participant.parse_names("Alice Bob Carol")).to eq(%w[Alice Bob Carol])
      end

      it "handles multiple spaces between names" do
        expect(Participant.parse_names("Alice    Bob     Carol")).to eq(%w[Alice Bob Carol])
      end

      it "handles leading and trailing whitespace" do
        expect(Participant.parse_names("   Alice Bob Carol   ")).to eq(%w[Alice Bob Carol])
      end

      it "handles tabs" do
        expect(Participant.parse_names("Alice\tBob\tCarol")).to eq(%w[Alice Bob Carol])
      end

      it "handles mixed whitespace" do
        expect(Participant.parse_names("Alice \t  Bob   \t Carol")).to eq(%w[Alice Bob Carol])
      end
    end

    context "separator precedence" do
      it "prefers commas over newlines" do
        input = "Alice, Bob\nCarol"
        expect(Participant.parse_names(input)).to eq(["Alice", "Bob Carol"])
      end

      it "prefers commas over periods" do
        expect(Participant.parse_names("Alice, Bob. Carol")).to eq(["Alice", "Bob. Carol"])
      end

      it "prefers commas over spaces" do
        expect(Participant.parse_names("Alice Smith, Bob Doe")).to eq(["Alice Smith", "Bob Doe"])
      end

      it "prefers newlines over periods" do
        input = "Alice. Smith\nBob. Doe"
        expect(Participant.parse_names(input)).to eq(["Alice. Smith", "Bob. Doe"])
      end

      it "prefers newlines over spaces" do
        input = "Alice Smith\nBob Doe"
        expect(Participant.parse_names(input)).to eq(["Alice Smith", "Bob Doe"])
      end

      it "prefers periods over spaces" do
        expect(Participant.parse_names("Alice Smith. Bob Doe")).to eq(["Alice Smith", "Bob Doe"])
      end
    end

    context "edge cases" do
      it "handles a single name" do
        expect(Participant.parse_names("Alice")).to eq(%w[Alice])
      end

      it "handles empty string" do
        expect(Participant.parse_names("")).to eq([])
      end

      it "handles only whitespace" do
        expect(Participant.parse_names("   \n\t  ")).to eq([])
      end

      it "handles only separators" do
        expect(Participant.parse_names(",,,")).to eq([])
        expect(Participant.parse_names("...")).to eq([])
        expect(Participant.parse_names("\n\n\n")).to eq([])
      end
    end
  end
end

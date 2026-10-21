require "rails_helper"

# Guards against the parser silently getting worse: each receipt in
# spec/fixtures/files/receipts is parsed for real and scored against its label
# in spec/fixtures/parsed_receipts (see ReceiptEval::Scorer for what counts).
#
# Excluded from the default suite: every example is a paid vision call.
#   bundle exec rspec --tag vision
#
# One run per receipt, and the same model reads the same receipt differently
# from run to run, so one red example is a prompt to look, not a verdict. To
# compare models, efforts or prompts, use repeated runs instead:
#   bin/rails receipts:eval RUNS=3 [MODEL=... EFFORT=... ONLY=1005,1086]
#
# The labels are the answer key, verified line by line against each receipt.
# Never refresh them from a parse: a model's reading is what is under test.
# bin/rails receipts:draft_labels writes a model's draft for a new receipt to
# tmp/ to start from.
RSpec.describe "receipt fixture regression", :vision do
  ReceiptEval::Fixture.labeled.each do |fixture|
    it "reads receipt #{fixture.id} the way its label records it" do
      parse = fixture.with_parser_inputs { |inputs| ReceiptParser.new(inputs).parse }
      result = ReceiptEval::Scorer.new(fixture.label, parse).score

      expect(result).to be_passed, result.report
    end
  end
end

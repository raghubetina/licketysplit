class AddParseRecordToChecks < ActiveRecord::Migration[8.1]
  # What the parser returned before anyone edited it, and which model and
  # effort produced it. Comparing this with the check people finally split
  # shows where parsing goes wrong on real receipts, which the fixture eval
  # can only approximate.
  def change
    add_column :checks, :parsed_receipt, :jsonb
    add_column :checks, :parse_model, :string
    add_column :checks, :parse_reasoning_effort, :string
    add_column :checks, :parse_seconds, :float
  end
end

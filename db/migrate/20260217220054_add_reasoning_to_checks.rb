class AddReasoningToChecks < ActiveRecord::Migration[8.0]
  def change
    add_column :checks, :reasoning, :text
  end
end

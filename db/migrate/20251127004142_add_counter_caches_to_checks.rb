class AddCounterCachesToChecks < ActiveRecord::Migration[8.0]
  def change
    add_column :checks, :line_items_count, :integer, default: 0, null: false
    add_column :checks, :participants_count, :integer, default: 0, null: false
  end
end

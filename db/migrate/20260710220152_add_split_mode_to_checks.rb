class AddSplitModeToChecks < ActiveRecord::Migration[8.0]
  def change
    add_column :checks, :split_mode, :string, default: "itemized", null: false
  end
end

class AddUnevenSharesToLineItemSplitting < ActiveRecord::Migration[8.0]
  def change
    add_column :line_item_participants, :shares, :integer, default: 1, null: false
    add_column :line_items, :uneven_split, :boolean, default: false, null: false
  end
end

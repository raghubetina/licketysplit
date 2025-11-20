class RenameColumnsAndTablesForConsistency < ActiveRecord::Migration[8.0]
  def change
    # Rename Check columns
    rename_column :checks, :receipt_at, :billed_on
    rename_column :checks, :total, :grand_total

    # Rename LineItem columns for consistency
    rename_column :line_items, :price, :unit_price
    rename_column :line_items, :line_item_total, :total_price

    # Rename Addon columns for consistency
    rename_column :addons, :price_per, :unit_price
    rename_column :addons, :addon_total, :total_price
    remove_column :addons, :price, :decimal, precision: 10, scale: 2

    # Rename tables: Fee -> GlobalFee, Discount -> GlobalDiscount
    rename_table :fees, :global_fees
    rename_table :discounts, :global_discounts
  end
end

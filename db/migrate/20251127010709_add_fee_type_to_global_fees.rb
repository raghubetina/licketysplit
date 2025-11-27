class AddFeeTypeToGlobalFees < ActiveRecord::Migration[8.0]
  def change
    add_column :global_fees, :fee_type, :string, default: "other", null: false
    add_index :global_fees, :fee_type
  end
end

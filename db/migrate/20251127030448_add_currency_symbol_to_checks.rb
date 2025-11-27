class AddCurrencySymbolToChecks < ActiveRecord::Migration[8.0]
  def change
    add_column :checks, :currency_symbol, :string, default: "$"
  end
end

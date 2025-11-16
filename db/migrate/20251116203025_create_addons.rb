class CreateAddons < ActiveRecord::Migration[8.0]
  def change
    create_table :addons, id: :uuid do |t|
      t.references :line_item, type: :uuid, null: false, foreign_key: true
      t.string :description, null: false
      t.integer :quantity, default: 1
      t.decimal :price_per, precision: 10, scale: 2
      t.decimal :price, precision: 10, scale: 2, null: false
      t.decimal :discount, precision: 10, scale: 2, default: 0
      t.string :discount_description
      t.decimal :addon_total, precision: 10, scale: 2

      t.timestamps
    end
  end
end

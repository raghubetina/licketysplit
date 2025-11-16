class CreateLineItems < ActiveRecord::Migration[8.0]
  def change
    create_table :line_items, id: :uuid do |t|
      t.references :check, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :quantity, default: 1
      t.decimal :price, precision: 10, scale: 2, null: false
      t.decimal :discount, precision: 10, scale: 2, default: 0
      t.string :discount_description
      t.decimal :line_item_total, precision: 10, scale: 2
      t.integer :shared_by_count, default: 1

      t.timestamps
    end
  end
end

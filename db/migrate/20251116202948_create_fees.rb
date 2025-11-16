class CreateFees < ActiveRecord::Migration[8.0]
  def change
    create_table :fees, id: :uuid do |t|
      t.references :check, type: :uuid, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :description, null: false

      t.timestamps
    end
  end
end

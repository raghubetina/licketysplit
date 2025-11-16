class CreateChecks < ActiveRecord::Migration[8.0]
  def change
    create_table :checks, id: :uuid do |t|
      t.datetime :receipt_at
      t.string :receipt_image
      t.string :restaurant_name
      t.string :restaurant_address
      t.string :restaurant_phone_number
      t.decimal :total, precision: 10, scale: 2
      t.string :currency, default: 'USD'
      t.string :status, default: 'draft' # draft, reviewing, finalized

      t.timestamps
    end

    add_index :checks, :status
  end
end

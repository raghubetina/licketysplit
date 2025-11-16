class CreateParticipants < ActiveRecord::Migration[8.0]
  def change
    create_table :participants, id: :uuid do |t|
      t.references :check, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.string :payment_status, default: 'unpaid' # unpaid, paid

      t.timestamps
    end

    add_index :participants, :payment_status
    add_index :participants, [:check_id, :name], unique: true
  end
end

class CreateLineItemParticipants < ActiveRecord::Migration[8.0]
  def change
    create_table :line_item_participants, id: :uuid do |t|
      t.references :line_item, type: :uuid, null: false, foreign_key: true
      t.references :participant, type: :uuid, null: false, foreign_key: true

      t.timestamps
    end

    add_index :line_item_participants, [:line_item_id, :participant_id], unique: true, name: 'index_line_item_participants_unique'
  end
end

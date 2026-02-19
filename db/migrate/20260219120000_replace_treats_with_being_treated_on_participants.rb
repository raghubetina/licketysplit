class ReplaceTreatsWithBeingTreatedOnParticipants < ActiveRecord::Migration[8.0]
  def up
    add_column :participants, :being_treated, :boolean, default: false, null: false
    drop_table :treats
  end

  def down
    create_table :treats, id: :uuid do |t|
      t.references :check, type: :uuid, null: false, foreign_key: true
      t.references :participant, type: :uuid, null: false, foreign_key: true

      t.timestamps
    end

    add_index :treats, [:check_id, :participant_id], unique: true
    remove_column :participants, :being_treated
  end
end

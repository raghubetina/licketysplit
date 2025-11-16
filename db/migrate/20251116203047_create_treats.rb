class CreateTreats < ActiveRecord::Migration[8.0]
  def change
    create_table :treats, id: :uuid do |t|
      t.references :check, type: :uuid, null: false, foreign_key: true
      t.references :participant, type: :uuid, null: false, foreign_key: true

      t.timestamps
    end

    add_index :treats, [:check_id, :participant_id], unique: true
  end
end

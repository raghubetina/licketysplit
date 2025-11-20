class AddPositionToLineItems < ActiveRecord::Migration[8.0]
  def change
    add_column :line_items, :position, :integer, default: 0
  end
end


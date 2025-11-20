class ConsolidateLineItemNameAndDescription < ActiveRecord::Migration[8.0]
  def up
    # First, copy any existing name values to description where description is null
    execute <<-SQL
      UPDATE line_items
      SET description = name
      WHERE description IS NULL OR description = ''
    SQL

    # For records that have both, concatenate them
    execute <<-SQL
      UPDATE line_items
      SET description = name || ' - ' || description
      WHERE description IS NOT NULL
      AND description != ''
      AND description != name
    SQL

    # Now make description not null and remove name
    change_column_null :line_items, :description, false
    remove_column :line_items, :name
  end

  def down
    # Add name column back
    add_column :line_items, :name, :string

    # Copy description to name (truncate if needed)
    execute <<-SQL
      UPDATE line_items
      SET name = LEFT(description, 255)
    SQL

    # Make name not null and description nullable
    change_column_null :line_items, :name, false
    change_column_null :line_items, :description, true
  end
end
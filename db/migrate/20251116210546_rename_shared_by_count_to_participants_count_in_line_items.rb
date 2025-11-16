class RenameSharedByCountToParticipantsCountInLineItems < ActiveRecord::Migration[8.0]
  def change
    rename_column :line_items, :shared_by_count, :participants_count
    change_column_default :line_items, :participants_count, 0
  end
end

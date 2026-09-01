class RemoveReceiptImageFromChecks < ActiveRecord::Migration[8.1]
  # Superseded by Active Storage (has_many_attached :receipt_images) before this
  # app had any users. Nothing reads it; its only effect was to make
  # `check.receipt_image.attach` in the import task fail with NoMethodError on
  # nil rather than NoMethodError on Check, which hid the real mistake.
  def change
    remove_column :checks, :receipt_image, :string
  end
end

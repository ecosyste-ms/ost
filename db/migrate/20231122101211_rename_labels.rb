class RenameLabels < ActiveRecord::Migration[7.1]
  def change
    rename_column :issues, :labels, :labels_raw
    add_column :issues, :labels, :string, array: true, default: []
  end
end

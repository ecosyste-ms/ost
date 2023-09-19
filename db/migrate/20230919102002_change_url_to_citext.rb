class ChangeUrlToCitext < ActiveRecord::Migration[7.0]
  def change
    enable_extension :citext
    change_column :projects, :url, :citext
  end
end

class AddUniqueUrlIndexToProjects < ActiveRecord::Migration[7.0]
  def change
    add_index :projects, :url, unique: true
  end
end

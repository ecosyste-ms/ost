class AddReadmeToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :readme, :text
  end
end

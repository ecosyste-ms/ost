class AddCategoriesToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :category, :string
    add_column :projects, :sub_category, :string
  end
end

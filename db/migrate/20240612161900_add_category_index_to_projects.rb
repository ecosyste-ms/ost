class AddCategoryIndexToProjects < ActiveRecord::Migration[7.1]
  def change
    add_index :projects, [:category, :sub_category], where: "(category IS NOT NULL) AND (sub_category IS NOT NULL)"
  end
end

class AddFieldsToContributors < ActiveRecord::Migration[7.1]
  def change
    add_column :contributors, :categories, :string, array: true, default: []
    add_column :contributors, :sub_categories, :string, array: true, default: []
    add_column :contributors, :reviewed_project_ids, :integer, array: true, default: []
    add_column :contributors, :reviewed_projects_count, :integer
  end
end

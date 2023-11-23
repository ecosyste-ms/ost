class AddProjectIdIndexToIssues < ActiveRecord::Migration[7.1]
  def change
    add_index :issues, :project_id
  end
end

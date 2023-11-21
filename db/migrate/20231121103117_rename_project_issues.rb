class RenameProjectIssues < ActiveRecord::Migration[7.1]
  def change
    rename_column :projects, :issues, :issues_stats
  end
end

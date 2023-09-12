class AddDependentReposToProjects < ActiveRecord::Migration[7.0]
  def change
    add_column :projects, :dependent_repos, :json
  end
end

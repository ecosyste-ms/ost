class AddDependenciesToProjects < ActiveRecord::Migration[7.0]
  def change
    add_column :projects, :dependencies, :json
  end
end

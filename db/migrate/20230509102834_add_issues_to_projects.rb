class AddIssuesToProjects < ActiveRecord::Migration[7.0]
  def change
    add_column :projects, :issues, :json
  end
end

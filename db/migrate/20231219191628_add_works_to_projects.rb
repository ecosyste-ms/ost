class AddWorksToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :works, :json, default: {}
  end
end

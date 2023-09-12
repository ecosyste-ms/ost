class AddOwnerToProjects < ActiveRecord::Migration[7.0]
  def change
    add_column :projects, :owner, :json
  end
end

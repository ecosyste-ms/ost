class AddEventsToProjects < ActiveRecord::Migration[7.0]
  def change
    add_column :projects, :events, :json
  end
end

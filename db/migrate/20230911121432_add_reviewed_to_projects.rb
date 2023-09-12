class AddReviewedToProjects < ActiveRecord::Migration[7.0]
  def change
    add_column :projects, :reviewed, :boolean
  end
end

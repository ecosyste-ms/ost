class AddReviewedProjectsIndex < ActiveRecord::Migration[7.2]
  def change
    add_index :projects, :reviewed
  end
end

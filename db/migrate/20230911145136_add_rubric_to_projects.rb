class AddRubricToProjects < ActiveRecord::Migration[7.0]
  def change
    add_column :projects, :rubric, :string
  end
end

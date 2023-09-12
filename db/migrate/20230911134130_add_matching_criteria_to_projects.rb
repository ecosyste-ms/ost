class AddMatchingCriteriaToProjects < ActiveRecord::Migration[7.0]
  def change
    add_column :projects, :matching_criteria, :boolean
  end
end

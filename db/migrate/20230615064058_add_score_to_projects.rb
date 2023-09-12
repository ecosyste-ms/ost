class AddScoreToProjects < ActiveRecord::Migration[7.0]
  def change
    add_column :projects, :score, :float, default: 0
  end
end

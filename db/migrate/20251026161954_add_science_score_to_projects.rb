class AddScienceScoreToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :joss_metadata, :json
    add_column :projects, :science_score, :float
    add_column :projects, :science_score_breakdown, :json, default: {}
  end
end

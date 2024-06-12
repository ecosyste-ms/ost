class AddKeywordsFromContributorsToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :keywords_from_contributors, :string, array: true, default: []
  end
end

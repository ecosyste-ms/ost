class AddCitationFileToProjects < ActiveRecord::Migration[7.0]
  def change
    add_column :projects, :citation_file, :text
  end
end

class AddEmbeddingsToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :embedding, :vector
  end
end

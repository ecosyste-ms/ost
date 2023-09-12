class CreateProjects < ActiveRecord::Migration[7.0]
  def change
    create_table :projects do |t|
      t.string :url
      t.json :repository
      t.json :packages
      t.json :commits
      
      t.timestamps
    end
  end
end

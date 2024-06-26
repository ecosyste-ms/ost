class CreateDependencies < ActiveRecord::Migration[7.1]
  def change
    create_table :dependencies do |t|
      t.string :ecosystem
      t.string :name
      t.integer :count
      t.json :package, default: {}
      t.string :repository_url
      t.integer :project_id
      t.float :average_ranking

      t.timestamps
    end
  end
end

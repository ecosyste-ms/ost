class CreateCollections < ActiveRecord::Migration[7.0]
  def change
    create_table :collections do |t|
      t.string :name
      t.string :description
      t.string :url
      t.integer :projects_count, null: false, default: 0

      t.timestamps
    end

    add_column :projects, :collection_id, :integer
    add_index :projects, :collection_id
  end
end

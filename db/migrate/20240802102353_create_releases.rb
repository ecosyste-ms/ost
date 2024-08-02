class CreateReleases < ActiveRecord::Migration[7.1]
  def change
    create_table :releases do |t|
      t.integer :project_id
      t.string :uuid
      t.string :tag_name
      t.string :target_commitish
      t.string :name
      t.text :body
      t.boolean :draft
      t.boolean :prerelease
      t.datetime :published_at
      t.string :author
      t.json :assets
      t.datetime :last_synced_at
      t.string :tag_url
      t.string :html_url

      t.timestamps
    end
  end
end

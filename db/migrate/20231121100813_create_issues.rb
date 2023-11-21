class CreateIssues < ActiveRecord::Migration[7.1]
  def change
    create_table :issues do |t|
      t.integer :project_id
      t.string :uuid
      t.string :node_id
      t.integer :number
      t.string :state
      t.string :title
      t.string :body
      t.string :user
      t.string :labels
      t.string :assignees
      t.boolean :locked
      t.integer :comments_count
      t.boolean :pull_request
      t.datetime :closed_at
      t.string :closed_by
      t.string :author_association
      t.string :state_reason
      t.integer :time_to_close
      t.datetime :merged_at
      t.json :dependency_metadata
      t.string :html_url
      t.string :url

      t.timestamps
    end
  end
end

class CreateVotes < ActiveRecord::Migration[7.0]
  def change
    create_table :votes do |t|
      t.integer :project_id
      t.integer :score

      t.timestamps
    end

    add_index :votes, :project_id
    add_column :projects, :vote_count, :integer, default: 0
    add_column :projects, :vote_score, :integer, default: 0
  end
end

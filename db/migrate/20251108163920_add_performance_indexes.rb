class AddPerformanceIndexes < ActiveRecord::Migration[7.2]
  def change
    add_index :contributors, :email
    add_index :projects, [:category, :score]
    add_index :projects, [:reviewed, :score]
  end
end

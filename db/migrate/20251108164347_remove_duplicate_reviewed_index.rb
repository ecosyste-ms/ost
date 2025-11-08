class RemoveDuplicateReviewedIndex < ActiveRecord::Migration[7.2]
  def change
    remove_index :projects, :reviewed
  end
end

class AddKeywordsToSummaries < ActiveRecord::Migration[7.0]
  def change
    add_column :projects, :keywords, :string, array: true, default: []
  end
end

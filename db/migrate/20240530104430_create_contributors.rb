class CreateContributors < ActiveRecord::Migration[7.1]
  def change
    create_table :contributors do |t|
      t.string :name
      t.string :email
      t.string :login
      t.string :topics, array: true, default: []
      t.datetime :last_synced_at

      t.timestamps
    end
  end
end

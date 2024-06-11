class AddProfileToContributors < ActiveRecord::Migration[7.1]
  def change
    add_column :contributors, :profile, :json, default: {}
  end
end

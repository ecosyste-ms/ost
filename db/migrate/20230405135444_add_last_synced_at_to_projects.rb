class AddLastSyncedAtToProjects < ActiveRecord::Migration[7.0]
  def change
    add_column :projects, :last_synced_at, :datetime
  end
end

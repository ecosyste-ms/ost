class AddMemoryOptimizations < ActiveRecord::Migration[8.0]
  def change
    # Add indexes to speed up common queries and reduce sequential scans
    add_index :contributors, :reviewed_projects_count
    add_index :projects, [:reviewed, :last_synced_at], where: "reviewed = true"

    # Add columns to avoid loading large text/json fields unnecessarily
    add_column :projects, :has_images, :boolean, default: false
    add_column :projects, :has_zenodo, :boolean, default: false

    # Add index on new boolean columns
    add_index :projects, :has_images, where: "has_images = true"
    add_index :projects, :has_zenodo, where: "has_zenodo = true"
  end
end

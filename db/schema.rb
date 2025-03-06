# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_03_06_083816) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "collections", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.string "url"
    t.integer "projects_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "contributors", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "login"
    t.string "topics", default: [], array: true
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "categories", default: [], array: true
    t.string "sub_categories", default: [], array: true
    t.integer "reviewed_project_ids", default: [], array: true
    t.integer "reviewed_projects_count"
    t.json "profile", default: {}
  end

  create_table "dependencies", force: :cascade do |t|
    t.string "ecosystem"
    t.string "name"
    t.integer "count"
    t.json "package", default: {}
    t.string "repository_url"
    t.integer "project_id"
    t.float "average_ranking"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "issues", force: :cascade do |t|
    t.integer "project_id"
    t.string "uuid"
    t.string "node_id"
    t.integer "number"
    t.string "state"
    t.string "title"
    t.string "body"
    t.string "user"
    t.string "labels_raw"
    t.string "assignees"
    t.boolean "locked"
    t.integer "comments_count"
    t.boolean "pull_request"
    t.datetime "closed_at"
    t.string "closed_by"
    t.string "author_association"
    t.string "state_reason"
    t.integer "time_to_close"
    t.datetime "merged_at"
    t.json "dependency_metadata"
    t.string "html_url"
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "labels", default: [], array: true
    t.index ["project_id"], name: "index_issues_on_project_id"
  end

# Could not dump table "projects" because of following StandardError
#   Unknown type 'vector' for column 'embedding'


  create_table "releases", force: :cascade do |t|
    t.integer "project_id"
    t.string "uuid"
    t.string "tag_name"
    t.string "target_commitish"
    t.string "name"
    t.text "body"
    t.boolean "draft"
    t.boolean "prerelease"
    t.datetime "published_at"
    t.string "author"
    t.json "assets"
    t.datetime "last_synced_at"
    t.string "tag_url"
    t.string "html_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "votes", force: :cascade do |t|
    t.integer "project_id"
    t.integer "score"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_votes_on_project_id"
  end
end

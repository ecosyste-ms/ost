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

ActiveRecord::Schema[7.1].define(version: 2024_06_26_125315) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "plpgsql"

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

  create_table "projects", force: :cascade do |t|
    t.citext "url"
    t.json "repository"
    t.json "packages"
    t.json "commits"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "dependent_repos"
    t.integer "collection_id"
    t.json "events"
    t.string "keywords", default: [], array: true
    t.json "dependencies"
    t.datetime "last_synced_at"
    t.json "issues_stats"
    t.float "score", default: 0.0
    t.json "owner"
    t.string "name"
    t.string "description"
    t.boolean "reviewed"
    t.boolean "matching_criteria"
    t.string "rubric"
    t.integer "vote_count", default: 0
    t.integer "vote_score", default: 0
    t.text "citation_file"
    t.string "category"
    t.string "sub_category"
    t.text "readme"
    t.json "works", default: {}
    t.string "keywords_from_contributors", default: [], array: true
    t.index ["category", "sub_category"], name: "index_projects_on_category_and_sub_category", where: "((category IS NOT NULL) AND (sub_category IS NOT NULL))"
    t.index ["collection_id"], name: "index_projects_on_collection_id"
    t.index ["url"], name: "index_projects_on_url", unique: true
  end

  create_table "votes", force: :cascade do |t|
    t.integer "project_id"
    t.integer "score"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_votes_on_project_id"
  end

end

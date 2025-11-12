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

ActiveRecord::Schema[8.1].define(version: 2025_11_12_104535) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"

  create_table "collections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "name"
    t.integer "projects_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "url"
  end

  create_table "contributors", force: :cascade do |t|
    t.string "categories", default: [], array: true
    t.datetime "created_at", null: false
    t.string "email"
    t.datetime "last_synced_at"
    t.string "login"
    t.string "name"
    t.json "profile", default: {}
    t.integer "reviewed_project_ids", default: [], array: true
    t.integer "reviewed_projects_count"
    t.string "sub_categories", default: [], array: true
    t.string "topics", default: [], array: true
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_contributors_on_email"
    t.index ["reviewed_projects_count"], name: "index_contributors_on_reviewed_projects_count"
  end

  create_table "dependencies", force: :cascade do |t|
    t.float "average_ranking"
    t.integer "count"
    t.datetime "created_at", null: false
    t.string "ecosystem"
    t.string "name"
    t.json "package", default: {}
    t.integer "project_id"
    t.string "repository_url"
    t.datetime "updated_at", null: false
  end

  create_table "issues", force: :cascade do |t|
    t.string "assignees"
    t.string "author_association"
    t.string "body"
    t.datetime "closed_at"
    t.string "closed_by"
    t.integer "comments_count"
    t.datetime "created_at", null: false
    t.json "dependency_metadata"
    t.string "html_url"
    t.string "labels", default: [], array: true
    t.string "labels_raw"
    t.boolean "locked"
    t.datetime "merged_at"
    t.string "node_id"
    t.integer "number"
    t.integer "project_id"
    t.boolean "pull_request"
    t.string "state"
    t.string "state_reason"
    t.integer "time_to_close"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url"
    t.string "user"
    t.string "uuid"
    t.index ["project_id"], name: "index_issues_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "category"
    t.text "citation_file"
    t.integer "collection_id"
    t.json "commits"
    t.datetime "created_at", null: false
    t.json "dependencies"
    t.json "dependent_repos"
    t.string "description"
    t.boolean "esd", default: false
    t.json "events"
    t.boolean "has_images", default: false
    t.boolean "has_zenodo", default: false
    t.json "issues_stats"
    t.json "joss_metadata"
    t.string "keywords", default: [], array: true
    t.string "keywords_from_contributors", default: [], array: true
    t.datetime "last_synced_at"
    t.boolean "matching_criteria"
    t.string "name"
    t.json "owner"
    t.json "packages"
    t.text "readme"
    t.json "repository"
    t.boolean "reviewed"
    t.string "rubric"
    t.float "science_score"
    t.json "science_score_breakdown", default: {}
    t.float "score", default: 0.0
    t.string "sub_category"
    t.datetime "updated_at", null: false
    t.citext "url"
    t.integer "vote_count", default: 0
    t.integer "vote_score", default: 0
    t.json "works", default: {}
    t.index ["category", "score"], name: "index_projects_on_category_and_score"
    t.index ["category", "sub_category"], name: "index_projects_on_category_and_sub_category", where: "((category IS NOT NULL) AND (sub_category IS NOT NULL))"
    t.index ["collection_id"], name: "index_projects_on_collection_id"
    t.index ["has_images"], name: "index_projects_on_has_images", where: "(has_images = true)"
    t.index ["has_zenodo"], name: "index_projects_on_has_zenodo", where: "(has_zenodo = true)"
    t.index ["reviewed", "last_synced_at"], name: "index_projects_on_reviewed_and_last_synced_at", where: "(reviewed = true)"
    t.index ["reviewed", "score"], name: "index_projects_on_reviewed_and_score"
    t.index ["url"], name: "index_projects_on_url", unique: true
  end

  create_table "releases", force: :cascade do |t|
    t.json "assets"
    t.string "author"
    t.text "body"
    t.datetime "created_at", null: false
    t.boolean "draft"
    t.string "html_url"
    t.datetime "last_synced_at"
    t.string "name"
    t.boolean "prerelease"
    t.integer "project_id"
    t.datetime "published_at"
    t.string "tag_name"
    t.string "tag_url"
    t.string "target_commitish"
    t.datetime "updated_at", null: false
    t.string "uuid"
  end

  create_table "votes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "project_id"
    t.integer "score"
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_votes_on_project_id"
  end
end

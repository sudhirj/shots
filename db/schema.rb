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

ActiveRecord::Schema.define(version: 2021_05_24_094022) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_stat_statements"
  enable_extension "plpgsql"

  create_table "centers", force: :cascade do |t|
    t.string "name", null: false
    t.integer "pincode", null: false
    t.text "address"
    t.text "block"
    t.time "open"
    t.time "close"
    t.string "fee_type"
    t.bigint "district_id", null: false
    t.datetime "created_at", precision: 6, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", precision: 6, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "map_url"
    t.string "map_image"
    t.decimal "lat"
    t.decimal "lon"
    t.index ["district_id"], name: "index_centers_on_district_id"
    t.index ["pincode"], name: "index_centers_on_pincode"
  end

  create_table "districts", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "state_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["state_id"], name: "index_districts_on_state_id"
  end

  create_table "geodata", force: :cascade do |t|
    t.integer "pincode"
    t.string "place"
    t.string "admin1"
    t.string "admin2"
    t.string "admin3"
    t.decimal "lat"
    t.decimal "lon"
    t.integer "accuracy"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["pincode"], name: "index_geodata_on_pincode"
  end

  create_table "pincodes", force: :cascade do |t|
    t.decimal "lat", default: "0.0", null: false
    t.decimal "lon", default: "0.0", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "map_url"
    t.string "map_image"
  end

  create_table "places", force: :cascade do |t|
    t.integer "pincode"
    t.string "area"
    t.string "city"
    t.string "area_slug"
    t.string "city_slug"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["city_slug", "area_slug", "pincode"], name: "index_places_on_city_slug_and_area_slug_and_pincode", unique: true
    t.index ["pincode"], name: "index_places_on_pincode"
  end

  create_table "sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.date "date", null: false
    t.integer "availability", default: 0, null: false
    t.string "vaccine", null: false
    t.integer "min_age", null: false
    t.bigint "center_id", null: false
    t.datetime "created_at", precision: 6, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", precision: 6, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["center_id"], name: "index_sessions_on_center_id"
  end

  create_table "states", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  add_foreign_key "centers", "districts"
  add_foreign_key "districts", "states"
  add_foreign_key "sessions", "centers"
end

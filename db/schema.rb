# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2019_06_03_152256) do

  create_table "routes", force: :cascade do |t|
    t.string "name"
    t.integer "vehicle_type"
    t.integer "external_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "routes_stops", id: false, force: :cascade do |t|
    t.integer "route_id", null: false
    t.integer "stop_id", null: false
    t.index ["route_id", "stop_id"], name: "index_routes_stops_on_route_id_and_stop_id", unique: true
  end

  create_table "stops", force: :cascade do |t|
    t.integer "code"
    t.string "name"
    t.float "longitude"
    t.float "latitude"
    t.integer "external_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "easyway_id"
    t.index ["code"], name: "index_stops_on_code", unique: true
  end

end

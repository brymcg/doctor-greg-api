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

ActiveRecord::Schema[7.1].define(version: 2025_07_19_214129) do
  create_schema "_heroku"

  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_stat_statements"
  enable_extension "plpgsql"

  create_table "conversations", force: :cascade do |t|
    t.bigint "user_id"
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "session_id"
    t.index ["session_id"], name: "index_conversations_on_session_id"
    t.index ["user_id"], name: "index_conversations_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.string "role"
    t.text "content"
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
  end

  create_table "terra_connections", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "provider"
    t.string "terra_user_id"
    t.string "reference_id"
    t.string "status"
    t.datetime "connected_at"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider"], name: "index_terra_connections_on_provider"
    t.index ["user_id", "status"], name: "index_terra_connections_on_user_active", where: "((status)::text = 'connected'::text)"
    t.index ["user_id"], name: "index_terra_connections_on_user_id"
  end

  create_table "terra_health_data", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "terra_connection_id", null: false
    t.string "data_type"
    t.string "provider"
    t.datetime "recorded_at"
    t.decimal "value"
    t.string "unit"
    t.text "metadata"
    t.jsonb "raw_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "recorded_at"], name: "index_terra_health_data_on_provider_date"
    t.index ["recorded_at"], name: "index_terra_health_data_on_recorded_at"
    t.index ["terra_connection_id", "recorded_at"], name: "index_terra_health_data_on_connection_date"
    t.index ["terra_connection_id"], name: "index_terra_health_data_on_terra_connection_id"
    t.index ["user_id", "data_type", "recorded_at"], name: "index_terra_health_data_on_user_type_date"
    t.index ["user_id"], name: "index_terra_health_data_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "first_name"
    t.string "last_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "date_of_birth"
    t.integer "height_cm"
    t.decimal "weight_kg"
    t.string "activity_level"
    t.string "biological_sex"
    t.string "time_zone"
    t.string "units_preference"
    t.datetime "onboarded_at"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "conversations", "users"
  add_foreign_key "messages", "conversations"
  add_foreign_key "terra_connections", "users"
  add_foreign_key "terra_health_data", "terra_connections"
  add_foreign_key "terra_health_data", "users"
end

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

ActiveRecord::Schema[8.1].define(version: 2026_05_25_210000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "actor_id"
    t.bigint "auditable_id", null: false
    t.string "auditable_type", null: false
    t.jsonb "changes_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.bigint "organization_id", null: false
    t.index ["actor_id"], name: "index_audit_logs_on_actor_id"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["organization_id", "created_at"], name: "index_audit_logs_on_organization_id_and_created_at"
    t.index ["organization_id"], name: "index_audit_logs_on_organization_id"
  end

  create_table "auth_tokens", force: :cascade do |t|
    t.string "channel", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "ip_address"
    t.string "purpose", default: "login", null: false
    t.string "short_code"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["expires_at"], name: "index_auth_tokens_on_expires_at"
    t.index ["token_digest"], name: "index_auth_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_auth_tokens_on_user_id"
  end

  create_table "boats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_active", default: true, null: false
    t.decimal "length_ft", precision: 5, scale: 1
    t.bigint "location_id", null: false
    t.string "make"
    t.string "model"
    t.string "name", null: false
    t.text "notes"
    t.bigint "owner_id", null: false
    t.bigint "slip_id"
    t.string "storage_type", null: false
    t.datetime "updated_at", null: false
    t.integer "year"
    t.index ["location_id"], name: "index_boats_on_location_id"
    t.index ["owner_id"], name: "index_boats_on_owner_id"
    t.index ["slip_id"], name: "index_boats_on_slip_id"
    t.index ["storage_type"], name: "index_boats_on_storage_type"
  end

  create_table "location_hours", force: :cascade do |t|
    t.time "close_time"
    t.boolean "closed", default: false, null: false
    t.datetime "created_at", null: false
    t.integer "day_of_week", null: false
    t.bigint "location_id", null: false
    t.time "open_time"
    t.datetime "updated_at", null: false
    t.index ["location_id", "day_of_week"], name: "index_location_hours_on_location_id_and_day_of_week", unique: true
    t.index ["location_id"], name: "index_location_hours_on_location_id"
  end

  create_table "location_subscriptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "location_id", null: false
    t.string "pushover_member_status"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["location_id"], name: "index_location_subscriptions_on_location_id"
    t.index ["user_id", "location_id"], name: "index_location_subscriptions_on_user_id_and_location_id", unique: true
    t.index ["user_id"], name: "index_location_subscriptions_on_user_id"
  end

  create_table "locations", force: :cascade do |t|
    t.string "address"
    t.datetime "created_at", null: false
    t.boolean "is_active", default: true, null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.string "pushover_group_key"
    t.string "slug", null: false
    t.integer "soft_cap_per_hour", default: 6, null: false
    t.string "timezone", default: "America/Chicago", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "slug"], name: "index_locations_on_organization_id_and_slug", unique: true
    t.index ["organization_id"], name: "index_locations_on_organization_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.integer "attempts", default: 0, null: false
    t.string "channel", null: false
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.text "error"
    t.string "event", null: false
    t.datetime "failed_at"
    t.string "provider_id"
    t.bigint "request_id"
    t.datetime "sent_at"
    t.string "status", default: "pending", null: false
    t.string "to_address", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["provider_id"], name: "index_notifications_on_provider_id"
    t.index ["request_id"], name: "index_notifications_on_request_id"
    t.index ["status"], name: "index_notifications_on_status"
    t.index ["user_id", "event"], name: "index_notifications_on_user_id_and_event"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "request_notes", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.bigint "request_id", null: false
    t.datetime "updated_at", null: false
    t.string "visibility", default: "private", null: false
    t.index ["author_id"], name: "index_request_notes_on_author_id"
    t.index ["request_id", "created_at"], name: "index_request_notes_on_request_id_and_created_at"
    t.index ["request_id"], name: "index_request_notes_on_request_id"
  end

  create_table "request_types", force: :cascade do |t|
    t.string "applicable_storage_types", default: [], null: false, array: true
    t.string "color", default: "#2563eb", null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.string "icon", default: "anchor", null: false
    t.boolean "is_active", default: true, null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.boolean "requires_description", default: false, null: false
    t.string "slug", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "slug"], name: "index_request_types_on_organization_id_and_slug", unique: true
    t.index ["organization_id"], name: "index_request_types_on_organization_id"
    t.index ["sort_order"], name: "index_request_types_on_sort_order"
  end

  create_table "requests", force: :cascade do |t|
    t.bigint "assigned_to_id"
    t.bigint "boat_id", null: false
    t.text "cancel_reason"
    t.datetime "cancelled_at"
    t.string "cancelled_by"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.text "description"
    t.bigint "location_id", null: false
    t.bigint "request_type_id", null: false
    t.datetime "scheduled_for", null: false
    t.datetime "started_at"
    t.string "status", default: "to_do", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_to_id"], name: "index_requests_on_assigned_to_id"
    t.index ["boat_id"], name: "index_requests_on_boat_id"
    t.index ["customer_id"], name: "index_requests_on_customer_id"
    t.index ["location_id", "scheduled_for"], name: "index_requests_on_location_id_and_scheduled_for"
    t.index ["location_id"], name: "index_requests_on_location_id"
    t.index ["request_type_id"], name: "index_requests_on_request_type_id"
    t.index ["scheduled_for"], name: "index_requests_on_scheduled_for"
    t.index ["status"], name: "index_requests_on_status"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "absolute_expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "ip_address"
    t.datetime "last_seen_at"
    t.datetime "revoked_at"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["expires_at"], name: "index_sessions_on_expires_at"
    t.index ["token_digest"], name: "index_sessions_on_token_digest", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "slips", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_active", default: true, null: false
    t.string "label", null: false
    t.bigint "location_id", null: false
    t.string "slip_type", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id", "label"], name: "index_slips_on_location_id_and_label", unique: true
    t.index ["location_id"], name: "index_slips_on_location_id"
    t.index ["slip_type"], name: "index_slips_on_slip_type"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.citext "email"
    t.boolean "is_active", default: true, null: false
    t.datetime "last_seen_at"
    t.string "name", null: false
    t.jsonb "notification_prefs", default: {}, null: false
    t.bigint "organization_id", null: false
    t.string "password_digest"
    t.string "phone"
    t.string "pushover_user_key"
    t.integer "role", default: 2, null: false
    t.datetime "updated_at", null: false
    t.string "venmo_handle"
    t.index ["organization_id", "email"], name: "index_users_on_organization_id_and_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["organization_id", "phone"], name: "index_users_on_organization_id_and_phone", unique: true, where: "(phone IS NOT NULL)"
    t.index ["organization_id"], name: "index_users_on_organization_id"
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "audit_logs", "organizations"
  add_foreign_key "audit_logs", "users", column: "actor_id"
  add_foreign_key "auth_tokens", "users"
  add_foreign_key "boats", "locations"
  add_foreign_key "boats", "slips"
  add_foreign_key "boats", "users", column: "owner_id"
  add_foreign_key "location_hours", "locations"
  add_foreign_key "location_subscriptions", "locations"
  add_foreign_key "location_subscriptions", "users"
  add_foreign_key "locations", "organizations"
  add_foreign_key "notifications", "requests"
  add_foreign_key "notifications", "users"
  add_foreign_key "request_notes", "requests"
  add_foreign_key "request_notes", "users", column: "author_id"
  add_foreign_key "request_types", "organizations"
  add_foreign_key "requests", "boats"
  add_foreign_key "requests", "locations"
  add_foreign_key "requests", "request_types"
  add_foreign_key "requests", "users", column: "assigned_to_id"
  add_foreign_key "requests", "users", column: "customer_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "slips", "locations"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "users", "organizations"
end

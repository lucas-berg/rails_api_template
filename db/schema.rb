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

ActiveRecord::Schema[8.1].define(version: 2026_11_18_170000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", precision: nil, null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_users", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.inet "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "last_sign_in_at", precision: nil
    t.inet "last_sign_in_ip"
    t.datetime "remember_created_at", precision: nil
    t.datetime "reset_password_sent_at", precision: nil
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "role", default: "support", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
    t.check_constraint "role::text = ANY (ARRAY['super_admin'::character varying::text, 'support'::character varying::text])", name: "admin_users_role_check"
  end

  create_table "audit_events", force: :cascade do |t|
    t.bigint "team_id"
    t.string "actor_type", null: false
    t.bigint "actor_id"
    t.string "action", null: false
    t.string "target_type", null: false
    t.bigint "target_id"
    t.string "request_id"
    t.string "reason"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_type", "actor_id"], name: "index_audit_events_on_actor_type_and_actor_id"
    t.index ["target_type", "target_id"], name: "index_audit_events_on_target_type_and_target_id"
    t.index ["team_id", "occurred_at", "id"], name: "index_audit_events_on_team_id_and_occurred_at_and_id"
    t.index ["team_id"], name: "index_audit_events_on_team_id"
  end

  create_table "auth_sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "jti_digest", null: false
    t.integer "credentials_version", null: false
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent", limit: 256
    t.inet "ip_address"
    t.index ["expires_at"], name: "index_auth_sessions_on_expires_at"
    t.index ["jti_digest"], name: "index_auth_sessions_on_jti_digest", unique: true
    t.index ["user_id"], name: "index_auth_sessions_on_user_id"
    t.check_constraint "credentials_version >= 0", name: "auth_sessions_version_nonnegative"
  end

  create_table "deletion_requests", force: :cascade do |t|
    t.string "uuid", null: false
    t.string "subject_type", null: false
    t.bigint "subject_id", null: false
    t.integer "requested_by_id"
    t.string "status", default: "pending", null: false
    t.string "stage", default: "requested", null: false
    t.string "previous_team_status"
    t.datetime "scheduled_at", null: false
    t.datetime "processing_started_at"
    t.datetime "completed_at"
    t.datetime "canceled_at"
    t.string "failure_code"
    t.integer "attempts", default: 0, null: false
    t.text "encrypted_recipient"
    t.datetime "notified_at"
    t.integer "notice_attempts", default: 0, null: false
    t.string "notice_failure_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["requested_by_id"], name: "index_deletion_requests_on_requested_by_id"
    t.index ["status", "scheduled_at"], name: "index_deletion_requests_on_status_and_scheduled_at"
    t.index ["subject_type", "subject_id"], name: "index_deletion_requests_on_open_subject", unique: true, where: "((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('processing'::character varying)::text, ('failed'::character varying)::text]))"
    t.index ["uuid"], name: "index_deletion_requests_on_uuid", unique: true
    t.check_constraint "attempts >= 0 AND notice_attempts >= 0", name: "deletion_requests_attempts_nonnegative"
    t.check_constraint "stage::text = ANY (ARRAY['requested'::character varying, 'ledger'::character varying, 'records'::character varying, 'completed'::character varying]::text[])", name: "deletion_requests_stage_allowed"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'processing'::character varying::text, 'failed'::character varying::text, 'completed'::character varying::text, 'canceled'::character varying::text])", name: "deletion_requests_status_allowed"
    t.check_constraint "subject_type::text = ANY (ARRAY['User'::character varying::text, 'Team'::character varying::text])", name: "deletion_requests_subject_allowed"
  end

  create_table "deletion_tombstones", force: :cascade do |t|
    t.string "request_uuid", null: false
    t.string "subject_type", null: false
    t.bigint "subject_id", null: false
    t.string "fingerprint", null: false
    t.datetime "deleted_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["request_uuid"], name: "index_deletion_tombstones_on_request_uuid", unique: true
    t.index ["subject_type", "subject_id"], name: "index_deletion_tombstones_on_subject_type_and_subject_id"
    t.check_constraint "subject_type::text = ANY (ARRAY['User'::character varying::text, 'Team'::character varying::text])", name: "deletion_tombstones_subject_allowed"
  end

  create_table "flipper_features", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "feature_key", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "good_job_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "callback_priority"
    t.text "callback_queue_name"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "discarded_at"
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "jobs_finished_at"
    t.text "on_discard"
    t.text "on_finish"
    t.text "on_success"
    t.jsonb "serialized_properties"
    t.datetime "updated_at", null: false
    t.index ["created_at", "id"], name: "index_good_job_batches_on_created_at_and_id", order: :desc
    t.index ["finished_at"], name: "index_good_job_batches_on_finished_at", where: "(finished_at IS NOT NULL)"
  end

  create_table "good_job_concurrency_claims", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "job_id", null: false
    t.uuid "locked_by_id"
    t.integer "state", limit: 2, null: false
    t.text "key", null: false
    t.index ["job_id"], name: "index_good_job_concurrency_claims_on_job_id"
    t.index ["key", "job_id"], name: "index_good_job_concurrency_claims_on_key_and_job_id", unique: true
    t.index ["key", "state", "created_at"], name: "index_good_job_concurrency_claims_for_promotion"
    t.index ["locked_by_id"], name: "index_good_job_concurrency_claims_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
  end

  create_table "good_job_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "active_job_id", null: false
    t.datetime "created_at", null: false
    t.interval "duration"
    t.text "error"
    t.text "error_backtrace", array: true
    t.integer "error_event", limit: 2
    t.datetime "finished_at"
    t.text "job_class"
    t.uuid "process_id"
    t.text "queue_name"
    t.datetime "scheduled_at"
    t.jsonb "serialized_params"
    t.datetime "updated_at", null: false
    t.index ["active_job_id", "created_at"], name: "index_good_job_executions_on_active_job_id_and_created_at"
    t.index ["created_at"], name: "index_good_job_executions_on_created_at"
    t.index ["process_id", "created_at"], name: "index_good_job_executions_on_process_id_and_created_at"
    t.index ["scheduled_at"], name: "index_good_job_executions_on_scheduled_at"
  end

  create_table "good_job_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "lock_type", limit: 2
    t.jsonb "state"
    t.datetime "updated_at", null: false
  end

  create_table "good_job_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "key"
    t.datetime "updated_at", null: false
    t.jsonb "value"
    t.index ["key"], name: "index_good_job_settings_on_key", unique: true
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "active_job_id"
    t.uuid "batch_callback_id"
    t.uuid "batch_id"
    t.text "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "cron_at"
    t.text "cron_key"
    t.text "error"
    t.integer "error_event", limit: 2
    t.integer "executions_count"
    t.datetime "finished_at"
    t.boolean "is_discrete"
    t.text "job_class"
    t.text "labels", array: true
    t.integer "lock_type", limit: 2
    t.datetime "locked_at"
    t.uuid "locked_by_id"
    t.datetime "performed_at"
    t.integer "priority"
    t.text "queue_name"
    t.uuid "retried_good_job_id"
    t.datetime "scheduled_at"
    t.jsonb "serialized_params"
    t.datetime "updated_at", null: false
    t.index ["active_job_id", "created_at"], name: "index_good_jobs_on_active_job_id_and_created_at"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id", where: "(batch_callback_id IS NOT NULL)"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id_unfinished", where: "((batch_callback_id IS NOT NULL) AND (finished_at IS NULL))"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id", where: "(batch_id IS NOT NULL)"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id_unfinished", where: "((batch_id IS NOT NULL) AND (finished_at IS NULL))"
    t.index ["concurrency_key", "created_at"], name: "index_good_jobs_on_concurrency_key_and_created_at"
    t.index ["concurrency_key"], name: "index_good_jobs_on_concurrency_key_when_unfinished", where: "(finished_at IS NULL)"
    t.index ["created_at"], name: "index_good_jobs_on_created_at"
    t.index ["cron_key", "created_at"], name: "index_good_jobs_on_cron_key_and_created_at_cond", where: "(cron_key IS NOT NULL)"
    t.index ["cron_key", "cron_at"], name: "index_good_jobs_on_cron_key_and_cron_at_cond", unique: true, order: { cron_at: "DESC NULLS LAST" }, where: "(cron_key IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_jobs_on_finished_at_only", where: "(finished_at IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_on_discarded", order: :desc, where: "((finished_at IS NOT NULL) AND (error IS NOT NULL))"
    t.index ["id"], name: "index_good_jobs_on_unfinished_or_errored", where: "((finished_at IS NULL) OR (error IS NOT NULL))"
    t.index ["job_class", "finished_at"], name: "index_good_jobs_on_discarded_job_class", where: "((finished_at IS NOT NULL) AND (error IS NOT NULL))"
    t.index ["job_class"], name: "index_good_jobs_on_job_class"
    t.index ["labels"], name: "index_good_jobs_on_labels", where: "(labels IS NOT NULL)", using: :gin
    t.index ["locked_by_id"], name: "index_good_jobs_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
    t.index ["priority", "created_at"], name: "index_good_job_jobs_for_candidate_lookup", where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at", "id"], name: "index_good_jobs_for_candidate_dequeue_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["priority", "scheduled_at", "id"], name: "index_good_jobs_on_priority_scheduled_at_unfinished", where: "(finished_at IS NULL)"
    t.index ["queue_name", "priority", "created_at"], name: "index_good_jobs_dequeue_by_queue", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "priority", "scheduled_at"], name: "index_good_jobs_dequeue_by_queue_scheduled_at", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "scheduled_at", "id"], name: "index_good_jobs_on_queue_name_priority_scheduled_at_unfinished", where: "(finished_at IS NULL)"
    t.index ["queue_name"], name: "index_good_jobs_on_queue_name"
    t.index ["scheduled_at", "queue_name"], name: "index_good_jobs_on_scheduled_at_and_queue_name"
    t.index ["scheduled_at"], name: "index_good_jobs_on_scheduled_at", where: "(finished_at IS NULL)"
  end

  create_table "invitations", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.integer "invited_by_id", null: false
    t.string "normalized_email", null: false
    t.string "role", default: "member", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "accepted_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["team_id", "normalized_email"], name: "index_invitations_on_pending_email", unique: true, where: "((accepted_at IS NULL) AND (revoked_at IS NULL))"
    t.index ["team_id"], name: "index_invitations_on_team_id"
    t.index ["token_digest"], name: "index_invitations_on_token_digest", unique: true
    t.check_constraint "role::text = ANY (ARRAY['admin'::character varying::text, 'member'::character varying::text, 'viewer'::character varying::text])", name: "invitations_role_allowed"
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.string "jti", null: false
    t.datetime "exp", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exp"], name: "index_jwt_denylists_on_exp"
    t.index ["jti"], name: "index_jwt_denylists_on_jti", unique: true
  end

  create_table "mail_deliveries", force: :cascade do |t|
    t.integer "user_id"
    t.bigint "team_id"
    t.string "kind", null: false
    t.string "event_key", null: false
    t.text "encrypted_payload"
    t.string "status", default: "pending", null: false
    t.integer "attempts", default: 0, null: false
    t.datetime "next_attempt_at", null: false
    t.datetime "locked_at"
    t.string "lease_token"
    t.datetime "sent_at"
    t.string "last_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_key"], name: "index_mail_deliveries_on_event_key", unique: true
    t.index ["status", "locked_at"], name: "index_mail_deliveries_on_status_and_locked_at"
    t.index ["status", "next_attempt_at"], name: "index_mail_deliveries_on_status_and_next_attempt_at"
    t.index ["team_id"], name: "index_mail_deliveries_on_team_id"
    t.index ["user_id"], name: "index_mail_deliveries_on_user_id"
    t.check_constraint "attempts >= 0", name: "mail_deliveries_attempts_valid"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'sending'::character varying::text, 'sent'::character varying::text, 'failed'::character varying::text, 'skipped'::character varying::text])", name: "mail_deliveries_status_valid"
  end

  create_table "members", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.integer "user_id", null: false
    t.string "role", default: "member", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id", "user_id"], name: "index_members_on_team_id_and_user_id", unique: true
    t.index ["team_id"], name: "index_members_on_team_id"
    t.index ["user_id"], name: "index_members_on_user_id"
    t.check_constraint "role::text = ANY (ARRAY['owner'::character varying::text, 'admin'::character varying::text, 'member'::character varying::text, 'viewer'::character varying::text])", name: "members_role_allowed"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'removed'::character varying::text])", name: "members_status_allowed"
  end

  create_table "notification_deliveries", force: :cascade do |t|
    t.bigint "notification_id", null: false
    t.string "channel", null: false
    t.string "status", default: "pending", null: false
    t.integer "attempts", default: 0, null: false
    t.datetime "next_attempt_at", null: false
    t.datetime "locked_at"
    t.string "lease_token"
    t.datetime "sent_at"
    t.string "last_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["channel", "status", "next_attempt_at"], name: "index_notification_deliveries_due"
    t.index ["notification_id", "channel"], name: "index_notification_deliveries_on_notification_id_and_channel", unique: true
    t.index ["notification_id"], name: "index_notification_deliveries_on_notification_id"
    t.check_constraint "attempts >= 0", name: "notification_attempts_nonnegative"
    t.check_constraint "channel::text = ANY (ARRAY['in_app'::character varying::text, 'email'::character varying::text])", name: "notification_channels_allowed"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'sending'::character varying::text, 'sent'::character varying::text, 'failed'::character varying::text, 'skipped'::character varying::text])", name: "notification_delivery_status_allowed"
  end

  create_table "notification_preferences", force: :cascade do |t|
    t.integer "user_id", null: false
    t.boolean "activity_in_app", default: true, null: false
    t.boolean "activity_email", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_notification_preferences_on_user_id", unique: true
  end

  create_table "notifications", force: :cascade do |t|
    t.integer "user_id", null: false
    t.bigint "team_id"
    t.string "event_key", null: false
    t.string "kind", null: false
    t.string "category", null: false
    t.datetime "visible_at"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id"], name: "index_notifications_on_team_id"
    t.index ["user_id", "event_key"], name: "index_notifications_on_user_id_and_event_key", unique: true
    t.index ["user_id", "team_id", "created_at"], name: "index_notifications_on_user_id_and_team_id_and_created_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
    t.check_constraint "category::text = 'security'::text AND team_id IS NULL OR category::text = 'activity'::text AND team_id IS NOT NULL", name: "notifications_category_team"
  end

  create_table "posts", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "teams", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "status", default: "active", null: false
    t.string "timezone", default: "UTC", null: false
    t.string "locale", default: "en", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["slug"], name: "index_teams_on_slug", unique: true
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'suspended'::character varying::text, 'deletion_pending'::character varying::text, 'deleting'::character varying::text, 'deleted'::character varying::text])", name: "teams_status_allowed"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.boolean "allow_password_change", default: false, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.inet "current_sign_in_ip"
    t.string "email"
    t.string "encrypted_password", default: "", null: false
    t.string "first_name", default: ""
    t.string "last_name", default: ""
    t.datetime "last_sign_in_at", precision: nil
    t.inet "last_sign_in_ip"
    t.string "provider", default: "email", null: false
    t.datetime "reset_password_sent_at", precision: nil
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.json "tokens"
    t.string "uid", default: "", null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "username", default: ""
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.string "status", default: "active", null: false
    t.integer "credentials_version", default: 0, null: false
    t.jsonb "preferences", default: {}, null: false
    t.datetime "deleted_at"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["uid", "provider"], name: "index_users_on_uid_and_provider", unique: true
    t.check_constraint "credentials_version >= 0", name: "users_credentials_version_nonnegative"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'suspended'::character varying::text])", name: "users_status_allowed"
  end

  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audit_events", "teams"
  add_foreign_key "auth_sessions", "users"
  add_foreign_key "deletion_requests", "users", column: "requested_by_id"
  add_foreign_key "invitations", "teams"
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "mail_deliveries", "teams", on_delete: :nullify
  add_foreign_key "mail_deliveries", "users", on_delete: :nullify
  add_foreign_key "members", "teams"
  add_foreign_key "members", "users"
  add_foreign_key "notification_deliveries", "notifications"
  add_foreign_key "notification_preferences", "users"
  add_foreign_key "notifications", "teams"
  add_foreign_key "notifications", "users"
end

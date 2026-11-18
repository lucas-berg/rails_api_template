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

ActiveRecord::Schema[8.1].define(version: 2026_11_18_190000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", precision: nil, null: false
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_users", id: :serial, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.datetime "created_at", precision: nil, null: false
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

  create_table "cart_items", force: :cascade do |t|
    t.bigint "cart_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", default: 1, null: false
    t.integer "unit_price_cents", null: false
    t.integer "total_cents", null: false
    t.string "currency", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cart_id", "product_id"], name: "index_cart_items_on_cart_id_and_product_id", unique: true
    t.index ["cart_id"], name: "index_cart_items_on_cart_id"
    t.index ["product_id"], name: "index_cart_items_on_product_id"
    t.check_constraint "quantity > 0", name: "cart_items_quantity_positive"
    t.check_constraint "unit_price_cents >= 0 AND total_cents >= 0", name: "cart_items_amounts_non_negative"
  end

  create_table "carts", force: :cascade do |t|
    t.bigint "store_id", null: false
    t.bigint "user_id", null: false
    t.string "status", default: "active", null: false
    t.string "currency", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["store_id", "user_id", "status"], name: "index_active_carts_on_store_and_user", unique: true, where: "((status)::text = 'active'::text)"
    t.index ["store_id"], name: "index_carts_on_store_id"
    t.index ["user_id"], name: "index_carts_on_user_id"
  end

  create_table "coupon_redemptions", force: :cascade do |t|
    t.bigint "store_id", null: false
    t.bigint "coupon_id", null: false
    t.bigint "user_id", null: false
    t.bigint "order_id", null: false
    t.integer "discount_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["coupon_id", "user_id"], name: "index_coupon_redemptions_on_coupon_id_and_user_id", unique: true
    t.index ["coupon_id"], name: "index_coupon_redemptions_on_coupon_id"
    t.index ["order_id"], name: "index_coupon_redemptions_on_order_id", unique: true
    t.index ["store_id"], name: "index_coupon_redemptions_on_store_id"
    t.index ["user_id"], name: "index_coupon_redemptions_on_user_id"
  end

  create_table "coupons", force: :cascade do |t|
    t.bigint "store_id", null: false
    t.string "code", null: false
    t.string "status", default: "active", null: false
    t.string "discount_type", null: false
    t.integer "discount_value", null: false
    t.integer "max_discount_cents"
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.integer "max_redemptions"
    t.integer "redemptions_count", default: 0, null: false
    t.integer "minimum_order_amount_cents", default: 0, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ends_at"], name: "index_coupons_on_ends_at"
    t.index ["starts_at"], name: "index_coupons_on_starts_at"
    t.index ["store_id", "code"], name: "index_coupons_on_store_id_and_code", unique: true
    t.index ["store_id", "status"], name: "index_coupons_on_store_id_and_status"
    t.index ["store_id"], name: "index_coupons_on_store_id"
    t.check_constraint "discount_value > 0 AND minimum_order_amount_cents >= 0 AND redemptions_count >= 0", name: "coupons_valid_values"
  end

  create_table "digital_assets", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.string "name", null: false
    t.boolean "active", default: true, null: false
    t.integer "max_downloads"
    t.integer "download_expires_in_seconds"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "active"], name: "index_digital_assets_on_product_id_and_active"
    t.index ["product_id"], name: "index_digital_assets_on_product_id"
  end

  create_table "download_grants", force: :cascade do |t|
    t.bigint "entitlement_id", null: false
    t.string "token_digest", null: false
    t.integer "downloads_count", default: 0, null: false
    t.integer "max_downloads"
    t.datetime "expires_at"
    t.datetime "last_downloaded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entitlement_id"], name: "index_download_grants_on_entitlement_id"
    t.index ["expires_at"], name: "index_download_grants_on_expires_at"
    t.index ["token_digest"], name: "index_download_grants_on_token_digest", unique: true
  end

  create_table "entitlements", force: :cascade do |t|
    t.bigint "store_id", null: false
    t.bigint "user_id", null: false
    t.bigint "order_id", null: false
    t.bigint "order_item_id", null: false
    t.bigint "product_id", null: false
    t.string "status", default: "active", null: false
    t.datetime "starts_at"
    t.datetime "expires_at"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_entitlements_on_order_id"
    t.index ["order_item_id"], name: "index_entitlements_on_order_item_id", unique: true
    t.index ["product_id"], name: "index_entitlements_on_product_id"
    t.index ["store_id", "user_id", "status"], name: "index_entitlements_on_store_id_and_user_id_and_status"
    t.index ["store_id"], name: "index_entitlements_on_store_id"
    t.index ["user_id"], name: "index_entitlements_on_user_id"
  end

  create_table "flipper_features", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.string "feature_key", null: false
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "good_job_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.jsonb "serialized_properties"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_discard"
    t.text "callback_queue_name"
    t.integer "callback_priority"
    t.datetime "enqueued_at"
    t.datetime "discarded_at"
    t.datetime "finished_at"
    t.datetime "jobs_finished_at"
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id", null: false
    t.text "job_class"
    t.text "queue_name"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.text "error"
    t.integer "error_event", limit: 2
    t.text "error_backtrace", array: true
    t.uuid "process_id"
    t.interval "duration"
    t.index ["active_job_id", "created_at"], name: "index_good_job_executions_on_active_job_id_and_created_at"
    t.index ["created_at"], name: "index_good_job_executions_on_created_at"
    t.index ["process_id", "created_at"], name: "index_good_job_executions_on_process_id_and_created_at"
    t.index ["scheduled_at"], name: "index_good_job_executions_on_scheduled_at"
  end

  create_table "good_job_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "state"
    t.integer "lock_type", limit: 2
  end

  create_table "good_job_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "key"
    t.jsonb "value"
    t.index ["key"], name: "index_good_job_settings_on_key", unique: true
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "queue_name"
    t.integer "priority"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "performed_at"
    t.datetime "finished_at"
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id"
    t.text "concurrency_key"
    t.text "cron_key"
    t.uuid "retried_good_job_id"
    t.datetime "cron_at"
    t.uuid "batch_id"
    t.uuid "batch_callback_id"
    t.boolean "is_discrete"
    t.integer "executions_count"
    t.text "job_class"
    t.integer "error_event", limit: 2
    t.text "labels", array: true
    t.uuid "locked_by_id"
    t.datetime "locked_at"
    t.integer "lock_type", limit: 2
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

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "product_id", null: false
    t.string "product_name", null: false
    t.string "product_slug", null: false
    t.string "sku"
    t.integer "quantity", default: 1, null: false
    t.integer "unit_price_cents", null: false
    t.integer "total_cents", null: false
    t.string "currency", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_id"], name: "index_order_items_on_product_id"
    t.check_constraint "quantity > 0 AND unit_price_cents >= 0 AND total_cents >= 0", name: "order_items_valid_amounts"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "store_id", null: false
    t.bigint "user_id", null: false
    t.string "number", null: false
    t.string "status", default: "pending_payment", null: false
    t.integer "subtotal_cents", default: 0, null: false
    t.integer "discount_cents", default: 0, null: false
    t.integer "total_cents", default: 0, null: false
    t.integer "wallet_amount_cents", default: 0, null: false
    t.integer "payable_amount_cents", default: 0, null: false
    t.string "coupon_code"
    t.string "currency", null: false
    t.datetime "paid_at"
    t.datetime "fulfilled_at"
    t.datetime "cancelled_at"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_orders_on_created_at"
    t.index ["number"], name: "index_orders_on_number", unique: true
    t.index ["store_id", "status"], name: "index_orders_on_store_id_and_status"
    t.index ["store_id", "user_id"], name: "index_orders_on_store_id_and_user_id"
    t.index ["store_id"], name: "index_orders_on_store_id"
    t.index ["user_id"], name: "index_orders_on_user_id"
    t.check_constraint "subtotal_cents >= 0 AND discount_cents >= 0 AND total_cents >= 0 AND wallet_amount_cents >= 0 AND payable_amount_cents >= 0", name: "orders_amounts_non_negative"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "store_id", null: false
    t.bigint "order_id", null: false
    t.bigint "user_id", null: false
    t.string "provider", null: false
    t.string "status", default: "pending", null: false
    t.integer "amount_cents", null: false
    t.string "currency", null: false
    t.string "provider_payment_id"
    t.string "provider_event_id"
    t.jsonb "raw_payload", default: {}, null: false
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_payments_on_order_id"
    t.index ["provider", "provider_event_id"], name: "index_payments_on_provider_and_provider_event_id", unique: true, where: "(provider_event_id IS NOT NULL)"
    t.index ["provider", "provider_payment_id"], name: "index_payments_on_provider_and_provider_payment_id", unique: true, where: "(provider_payment_id IS NOT NULL)"
    t.index ["store_id", "status"], name: "index_payments_on_store_id_and_status"
    t.index ["store_id"], name: "index_payments_on_store_id"
    t.index ["user_id"], name: "index_payments_on_user_id"
    t.check_constraint "amount_cents >= 0", name: "payments_amount_non_negative"
  end

  create_table "posts", force: :cascade do |t|
    t.string "title"
    t.text "content"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "product_price_changes", force: :cascade do |t|
    t.bigint "store_id", null: false
    t.bigint "product_id", null: false
    t.bigint "admin_user_id", null: false
    t.integer "old_price_cents", null: false
    t.integer "new_price_cents", null: false
    t.string "old_currency", null: false
    t.string "new_currency", null: false
    t.text "reason"
    t.datetime "created_at", null: false
    t.index ["admin_user_id"], name: "index_product_price_changes_on_admin_user_id"
    t.index ["product_id"], name: "index_product_price_changes_on_product_id"
    t.index ["store_id"], name: "index_product_price_changes_on_store_id"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "store_id", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.string "status", default: "draft", null: false
    t.string "sku"
    t.integer "price_cents", default: 0, null: false
    t.string "currency", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["store_id", "sku"], name: "index_products_on_store_id_and_sku", unique: true, where: "(sku IS NOT NULL)"
    t.index ["store_id", "slug"], name: "index_products_on_store_id_and_slug", unique: true
    t.index ["store_id", "status"], name: "index_products_on_store_id_and_status"
    t.index ["store_id"], name: "index_products_on_store_id"
    t.check_constraint "price_cents >= 0", name: "products_price_non_negative"
  end

  create_table "settings", force: :cascade do |t|
    t.string "key", null: false
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "stores", force: :cascade do |t|
    t.string "uid", null: false
    t.string "name", null: false
    t.string "code"
    t.string "status", default: "active", null: false
    t.string "default_currency", default: "CNY", null: false
    t.string "support_email"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_stores_on_status"
    t.index ["uid"], name: "index_stores_on_uid", unique: true
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
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'suspended'::character varying::text, 'deleted'::character varying::text])", name: "teams_status_allowed"
  end

  create_table "tracing_events", force: :cascade do |t|
    t.uuid "run_id", null: false
    t.string "name", null: false
    t.datetime "event_time", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["run_id", "event_time"], name: "index_tracing_events_on_run_id_and_event_time"
  end

  create_table "tracing_projects", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "name"], name: "index_tracing_projects_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_tracing_projects_on_user_id"
  end

  create_table "tracing_raw_payloads", force: :cascade do |t|
    t.string "http_method", null: false
    t.string "path", null: false
    t.string "query_string"
    t.jsonb "headers", default: {}, null: false
    t.jsonb "body", default: {}, null: false
    t.string "client_ip"
    t.bigint "user_id"
    t.uuid "project_id"
    t.uuid "run_id"
    t.string "operation", null: false
    t.string "processing_status", default: "received", null: false
    t.text "processing_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_tracing_raw_payloads_on_created_at"
    t.index ["processing_status"], name: "index_tracing_raw_payloads_on_processing_status"
    t.index ["run_id"], name: "index_tracing_raw_payloads_on_run_id"
    t.index ["user_id", "created_at"], name: "index_tracing_raw_payloads_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_tracing_raw_payloads_on_user_id"
  end

  create_table "tracing_runs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "project_id", null: false
    t.uuid "trace_id", null: false
    t.uuid "parent_run_id"
    t.string "dotted_order"
    t.string "name", null: false
    t.string "run_type", default: "chain", null: false
    t.string "status", default: "pending", null: false
    t.text "error"
    t.datetime "start_time"
    t.datetime "end_time"
    t.jsonb "inputs", default: {}, null: false
    t.jsonb "outputs", default: {}, null: false
    t.jsonb "extra", default: {}, null: false
    t.text "tags", default: [], array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["extra"], name: "index_tracing_runs_on_extra", using: :gin
    t.index ["parent_run_id"], name: "index_tracing_runs_on_parent_run_id"
    t.index ["project_id", "start_time"], name: "index_tracing_runs_on_project_id_and_start_time", order: { start_time: :desc }
    t.index ["tags"], name: "index_tracing_runs_on_tags", using: :gin
    t.index ["trace_id", "dotted_order"], name: "index_tracing_runs_on_trace_id_and_dotted_order"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "email"
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.boolean "allow_password_change", default: false, null: false
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.string "first_name", default: ""
    t.string "last_name", default: ""
    t.string "username", default: ""
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "provider", default: "email", null: false
    t.string "uid", default: "", null: false
    t.json "tokens"
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

  create_table "wallet_accounts", force: :cascade do |t|
    t.bigint "store_id", null: false
    t.bigint "user_id", null: false
    t.integer "balance_cents", default: 0, null: false
    t.string "currency", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_wallet_accounts_on_status"
    t.index ["store_id", "user_id"], name: "index_wallet_accounts_on_store_id_and_user_id", unique: true
    t.index ["store_id"], name: "index_wallet_accounts_on_store_id"
    t.index ["user_id"], name: "index_wallet_accounts_on_user_id"
    t.check_constraint "balance_cents >= 0", name: "wallet_accounts_balance_non_negative"
  end

  create_table "wallet_transactions", force: :cascade do |t|
    t.bigint "store_id", null: false
    t.bigint "wallet_account_id", null: false
    t.bigint "user_id", null: false
    t.bigint "order_id"
    t.bigint "payment_id"
    t.string "transaction_type", null: false
    t.string "direction", null: false
    t.integer "amount_cents", null: false
    t.integer "balance_after_cents", null: false
    t.string "currency", null: false
    t.string "status", default: "succeeded", null: false
    t.string "reference_type"
    t.bigint "reference_id"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_wallet_transactions_on_created_at"
    t.index ["order_id"], name: "index_wallet_transactions_on_order_id"
    t.index ["payment_id"], name: "index_wallet_transactions_on_payment_id"
    t.index ["reference_type", "reference_id"], name: "index_wallet_transactions_on_reference"
    t.index ["store_id"], name: "index_wallet_transactions_on_store_id"
    t.index ["user_id"], name: "index_wallet_transactions_on_user_id"
    t.index ["wallet_account_id"], name: "index_wallet_transactions_on_wallet_account_id"
    t.check_constraint "amount_cents > 0 AND balance_after_cents >= 0", name: "wallet_transactions_valid_amounts"
  end

  create_table "webhook_requests", force: :cascade do |t|
    t.bigint "webhook_id", null: false
    t.string "request_method", null: false
    t.text "request_path", null: false
    t.jsonb "query_params", default: {}, null: false
    t.jsonb "headers", default: {}, null: false
    t.string "content_type"
    t.text "raw_body"
    t.boolean "body_truncated", default: false, null: false
    t.integer "body_size", default: 0, null: false
    t.jsonb "parsed_json"
    t.jsonb "form_params"
    t.inet "remote_ip"
    t.text "user_agent"
    t.integer "response_status", null: false
    t.datetime "received_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["request_method"], name: "index_webhook_requests_on_request_method"
    t.index ["webhook_id", "received_at"], name: "index_webhook_requests_on_webhook_id_and_received_at"
    t.index ["webhook_id"], name: "index_webhook_requests_on_webhook_id"
  end

  create_table "webhooks", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "uuid", null: false
    t.string "name", default: "Default inbox", null: false
    t.boolean "active", default: true, null: false
    t.integer "default_response_status", default: 200, null: false
    t.string "default_response_content_type", default: "text/plain", null: false
    t.text "default_response_body", default: "OK", null: false
    t.boolean "cors_enabled", default: true, null: false
    t.integer "retention_count", default: 100, null: false
    t.integer "retention_days", default: 30, null: false
    t.integer "request_count", default: 0, null: false
    t.datetime "last_request_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "created_at"], name: "index_webhooks_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_webhooks_on_user_id"
    t.index ["uuid"], name: "index_webhooks_on_uuid", unique: true
  end

  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audit_events", "teams"
  add_foreign_key "auth_sessions", "users"
  add_foreign_key "cart_items", "carts"
  add_foreign_key "cart_items", "products"
  add_foreign_key "carts", "stores"
  add_foreign_key "carts", "users"
  add_foreign_key "coupon_redemptions", "coupons"
  add_foreign_key "coupon_redemptions", "orders"
  add_foreign_key "coupon_redemptions", "stores"
  add_foreign_key "coupon_redemptions", "users"
  add_foreign_key "coupons", "stores"
  add_foreign_key "digital_assets", "products"
  add_foreign_key "download_grants", "entitlements"
  add_foreign_key "entitlements", "order_items"
  add_foreign_key "entitlements", "orders"
  add_foreign_key "entitlements", "products"
  add_foreign_key "entitlements", "stores"
  add_foreign_key "entitlements", "users"
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
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "products"
  add_foreign_key "orders", "stores"
  add_foreign_key "orders", "users"
  add_foreign_key "payments", "orders"
  add_foreign_key "payments", "stores"
  add_foreign_key "payments", "users"
  add_foreign_key "product_price_changes", "admin_users"
  add_foreign_key "product_price_changes", "products"
  add_foreign_key "product_price_changes", "stores"
  add_foreign_key "products", "stores"
  add_foreign_key "tracing_events", "tracing_runs", column: "run_id"
  add_foreign_key "tracing_projects", "users"
  add_foreign_key "tracing_raw_payloads", "users", on_delete: :nullify
  add_foreign_key "tracing_runs", "tracing_projects", column: "project_id"
  add_foreign_key "wallet_accounts", "stores"
  add_foreign_key "wallet_accounts", "users"
  add_foreign_key "wallet_transactions", "orders"
  add_foreign_key "wallet_transactions", "payments"
  add_foreign_key "wallet_transactions", "stores"
  add_foreign_key "wallet_transactions", "users"
  add_foreign_key "wallet_transactions", "wallet_accounts"
  add_foreign_key "webhook_requests", "webhooks"
  add_foreign_key "webhooks", "users"
end
